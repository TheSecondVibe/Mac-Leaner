import Testing
import Foundation
@testable import MacLeaner

/// Every test runs the engine against a TemporaryHome, and only with permanent
/// actions on paths inside it. `.moveToTrash` is never run: it would use the
/// real user's Trash. Trash rules are covered through `SafetyPolicy.validate`.
@Suite("CleanerEngine")
struct CleanerEngineTests {

    /// Builds the item the way the scanner does, measuring it with FileSizer.
    private func scannedItem(_ url: URL, _ category: CleanCategory, _ action: CleanAction) -> CleanableItem {
        let usage = FileSizer.measure(url)
        return CleanableItem(
            url: url, name: url.lastPathComponent, detail: "", category: category,
            size: usage.size, fileCount: usage.fileCount, lastModified: usage.newestModification,
            isDirectory: usage.isDirectory, safety: .safe, action: action, selectedByDefault: true
        )
    }

    private func clean(_ items: [CleanableItem], in home: TemporaryHome) async throws -> CleanReport {
        // Guard rails: nothing may reach the real Trash or leave the temporary home.
        try #require(!items.contains(where: { $0.action == .moveToTrash }))
        try #require(items.allSatisfy { $0.url.path.hasPrefix(home.root.path + "/") })
        return await CleanerEngine(policy: SafetyPolicy(home: home.root)).clean(items)
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    @Test func emptyContentsRemovesChildrenButKeepsTheFolder() async throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let derivedData = try home.makeDirectory("Library/Developer/Xcode/DerivedData")
        try home.makeFile("Library/Developer/Xcode/DerivedData/MyApp-abc/Build/Products/MyApp.o", bytes: 300_000)
        try home.makeFile("Library/Developer/Xcode/DerivedData/ModuleCache.noindex/Foundation.pcm", bytes: 200_000)
        try home.makeFile("Library/Developer/Xcode/DerivedData/.index-lock", bytes: 4_000)
        let item = scannedItem(derivedData, .developer, .emptyContents)
        #expect(item.size >= 504_000)

        let report = try await clean([item], in: home)

        #expect(report.failures.isEmpty)
        #expect(report.cleanedIDs == [item.id])
        #expect(report.freedBytes == item.size)
        #expect(report.trashedBytes == 0)
        #expect(isDirectory(derivedData))
        #expect(try FileManager.default.contentsOfDirectory(atPath: derivedData.path).isEmpty)
    }

    @Test func deleteRemovesAFileInCaches() async throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let file = try home.makeFile("Library/Caches/com.example.app.db", bytes: 150_000)
        let neighbour = try home.makeFile("Library/Caches/com.example.other/keep.bin", bytes: 10_000)
        let item = scannedItem(file, .appCaches, .delete)
        #expect(!item.isDirectory)
        #expect(item.size >= 150_000)

        let report = try await clean([item], in: home)

        #expect(report.failures.isEmpty)
        #expect(report.cleanedIDs == [item.id])
        #expect(report.freedBytes == item.size)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(FileManager.default.fileExists(atPath: neighbour.path))
        #expect(isDirectory(home.url("Library/Caches")))
    }

    @Test func itemThatIsAlreadyGoneCountsAsCleaned() async throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let folder = try home.makeDirectory("Library/Caches/com.example.gone")
        try home.makeFile("Library/Caches/com.example.gone/blob.bin", bytes: 100_000)
        let item = scannedItem(folder, .appCaches, .emptyContents)
        #expect(item.size > 0)
        // The app clears its own cache between the scan and the clean.
        try FileManager.default.removeItem(at: folder)

        let report = try await clean([item], in: home)

        #expect(report.failures.isEmpty)
        #expect(report.cleanedIDs == [item.id])
        #expect(report.freedBytes == 0)
    }

    @Test func policyViolationIsReportedAndTheFileIsLeftAlone() async throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let document = try home.makeFile("Documents/report.pdf", bytes: 50_000)
        let original = try Data(contentsOf: document)
        // A scanner bug: a document mislabelled as an app cache.
        let violating = scannedItem(document, .appCaches, .delete)
        let cache = try home.makeDirectory("Library/Caches/com.example.app")
        try home.makeFile("Library/Caches/com.example.app/blob.bin", bytes: 20_000)
        let valid = scannedItem(cache, .appCaches, .emptyContents)

        let report = try await clean([violating, valid], in: home)

        #expect(report.failures.count == 1)
        let failure = try #require(report.failures.first)
        #expect(failure.path == document.path)
        #expect(failure.reason == SafetyPolicy.Violation.permanentDeletionNotAllowed.localizedDescription)
        #expect(!report.cleanedIDs.contains(violating.id))
        #expect(try Data(contentsOf: document) == original)
        // The rest of the batch still runs.
        #expect(report.cleanedIDs == [valid.id])
        #expect(report.freedBytes == valid.size)
    }

    @Test(.enabled(if: geteuid() != 0, "File permissions don't stop root"))
    func partialFailureIsReportedAndOnlyRemovedBytesCount() async throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let folder = try home.makeDirectory("Library/Caches/com.example.partial")
        let removable = try home.makeFile("Library/Caches/com.example.partial/removable.bin", bytes: 400_000)
        let stuck = try home.makeFile("Library/Caches/com.example.partial/locked/stuck.bin", bytes: 200_000)
        let locked = stuck.deletingLastPathComponent()
        let item = scannedItem(folder, .appCaches, .emptyContents)

        // A read-only folder: the file inside it can't be unlinked.
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        // Declared after `home.remove()`, so it runs first and cleanup can delete everything.
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }

        let report = try await clean([item], in: home)

        #expect(report.failures.count == 1)
        let failure = try #require(report.failures.first)
        #expect(failure.path == folder.path)
        #expect(failure.reason.hasPrefix("1 of 2 "), "\(failure.reason)")
        #expect(!report.cleanedIDs.contains(item.id))
        #expect(report.freedBytes < item.size)
        #expect(report.freedBytes >= 400_000, "removable.bin was removed and should count")
        #expect(report.freedBytes == item.size - FileSizer.measure(folder).size)
        #expect(isDirectory(folder))
        #expect(!FileManager.default.fileExists(atPath: removable.path))
        #expect(FileManager.default.fileExists(atPath: stuck.path))
    }
}

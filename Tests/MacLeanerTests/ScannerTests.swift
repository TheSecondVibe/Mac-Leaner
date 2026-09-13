import Testing
import Foundation
@testable import MacLeaner

// MARK: - FileSizer

@Suite("FileSizer")
struct FileSizerTests {
    @Test func folderMeasuresAtLeastItsFiles() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        try home.makeFile("Folder/a.bin", bytes: 10_000)
        try home.makeFile("Folder/nested/b.bin", bytes: 25_000)

        let usage = FileSizer.measure(home.url("Folder"))

        #expect(usage.isDirectory)
        #expect(usage.fileCount == 2)
        #expect(usage.size >= 35_000)
        #expect(usage.size < 35_000 + 128 * 1024, "Only the two files' blocks should count")
    }

    @Test func symlinksAreNotFollowed() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let big = try home.makeFile("Elsewhere/big.bin", bytes: 4_000_000)
        let folder = try home.makeDirectory("Folder")
        let fileLink = folder.appendingPathComponent("big-link")
        let folderLink = folder.appendingPathComponent("elsewhere-link")
        try FileManager.default.createSymbolicLink(at: fileLink, withDestinationURL: big)
        try FileManager.default.createSymbolicLink(at: folderLink, withDestinationURL: big.deletingLastPathComponent())

        #expect(FileSizer.measure(big).size >= 4_000_000)
        #expect(FileSizer.measure(fileLink).size < 64 * 1024)
        #expect(FileSizer.measure(folderLink).size < 64 * 1024)
        let usage = FileSizer.measure(folder)
        #expect(usage.size < 64 * 1024)
        #expect(usage.fileCount == 0)
    }

    @Test func sparseFileCountsOnlyAllocatedBlocks() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let file = home.url("Docker.raw")
        try #require(FileManager.default.createFile(atPath: file.path, contents: nil))
        let handle = try FileHandle(forWritingTo: file)
        try handle.seek(toOffset: 1 << 30)
        try handle.write(contentsOf: Data([0x01]))
        try handle.close()

        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        let logicalSize = try #require((attributes[.size] as? NSNumber)?.int64Value)
        #expect(logicalSize == (1 << 30) + 1)

        let usage = FileSizer.measure(file)
        #expect(usage.size > 0)
        #expect(usage.size < 16 << 20, "A sparse 1 GB file occupies a few KB, not \(usage.size.byteString)")
        #expect(usage.fileCount == 1)
        #expect(!usage.isDirectory)
    }

    @Test func newestModificationIsTheNewestFileDate() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let newest = Date(timeIntervalSince1970: 1_717_000_000)
        let dated: [(path: String, date: Date)] = [
            ("Folder/old.log", Date(timeIntervalSince1970: 1_500_000_000)),
            ("Folder/nested/newest.log", newest),
            ("Folder/middle.log", Date(timeIntervalSince1970: 1_650_000_000)),
        ]
        for entry in dated {
            let file = try home.makeFile(entry.path, bytes: 1_000)
            try FileManager.default.setAttributes([.modificationDate: entry.date], ofItemAtPath: file.path)
        }

        let usage = FileSizer.measure(home.url("Folder"))

        // The folders themselves were modified just now; only files count.
        let measured = try #require(usage.newestModification)
        #expect(abs(measured.timeIntervalSince(newest)) < 1)
    }
}

// MARK: - DiskScanner

@Suite("DiskScanner")
struct DiskScannerTests {
    private func context(_ home: TemporaryHome, largeFileThreshold: Int64 = 1_000_000) -> ScanContext {
        ScanContext(
            home: home.root, largeFileThreshold: largeFileThreshold, leftoverIdleDays: 90,
            hasFullDiskAccess: false, ownBundleID: nil
        )
    }

    @Test func eachLogsFolderIsItsOwnItem() async throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        try home.makeFile("Library/Logs/DiagnosticReports/a.crash", bytes: 100_000)
        try home.makeFile("Library/Logs/App/x.log", bytes: 100_000)

        let items = await DiskScanner.scan(.logs, in: context(home))

        #expect(items.count == 2)
        #expect(Set(items.map(\.name)) == ["Crash Reports", "App"])
        // No double counting: every byte in ~/Library/Logs belongs to exactly one item.
        let total = items.reduce(Int64(0)) { $0 + $1.size }
        #expect(total == FileSizer.measure(home.url("Library/Logs")).size)
        for item in items {
            #expect(item.size >= 100_000 && item.size < 200_000, "\(item.name)")
            #expect(item.category == .logs)
            #expect(item.action == .emptyContents)
            #expect(item.selectedByDefault)
        }
    }

    @Test func appCachesSkipSystemAndClaimedFolders() async throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        try home.makeFile("Library/Caches/com.example.foo/data.bin", bytes: 2_000_000)
        try home.makeFile("Library/Caches/com.apple.bar/data.bin", bytes: 2_000_000)
        try home.makeFile("Library/Caches/Homebrew/downloads/bottle.tar.gz", bytes: 2_000_000)

        let appCaches = await DiskScanner.scan(.appCaches, in: context(home))

        #expect(appCaches.map(\.url.lastPathComponent) == ["com.example.foo"])
        let foo = try #require(appCaches.first)
        #expect(foo.category == .appCaches)
        #expect(foo.action == .emptyContents)
        #expect(foo.selectedByDefault)
        #expect(foo.ownerBundleID == "com.example.foo")
        #expect(foo.size >= 2_000_000)
        #expect(throws: Never.self) { try SafetyPolicy(home: home.root).validate(foo) }

        // Homebrew is claimed by Package Caches instead.
        let packageCaches = await DiskScanner.scan(.packageCaches, in: context(home))
        #expect(packageCaches.map(\.url.lastPathComponent) == ["Homebrew"])
        #expect(packageCaches.first?.category == .packageCaches)
    }

    @Test func largeFilesAreReviewOnlyAndGoToTheTrash() async throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        try home.makeFile("Downloads/big.bin", bytes: 2_000_000)
        try home.makeFile("Downloads/small.bin", bytes: 100_000)

        let items = await DiskScanner.scan(.largeFiles, in: context(home, largeFileThreshold: 1_000_000))

        #expect(items.map(\.name) == ["big.bin"])
        let big = try #require(items.first)
        #expect(big.category == .largeFiles)
        #expect(big.action == .moveToTrash)
        #expect(big.selectedByDefault == false)
        #expect(big.safety == .review)
        #expect(big.size >= 2_000_000)
        // Validation only: running the engine would move it into the real Trash.
        #expect(throws: Never.self) { try SafetyPolicy(home: home.root).validate(big) }
    }

    @Test func derivedDataIsEmptiedAndPreselected() async throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        try home.makeFile("Library/Developer/Xcode/DerivedData/MyApp-abc/Build/MyApp.o", bytes: 500_000)
        // Present but empty: nothing to offer.
        try home.makeDirectory("Library/Developer/Xcode/iOS DeviceSupport")

        let items = await DiskScanner.scan(.developer, in: context(home))

        #expect(items.map(\.name) == ["Xcode DerivedData"])
        let derivedData = try #require(items.first)
        #expect(derivedData.url.lastPathComponent == "DerivedData")
        #expect(derivedData.category == .developer)
        #expect(derivedData.action == .emptyContents)
        #expect(derivedData.selectedByDefault)
        #expect(derivedData.size >= 500_000)
        #expect(throws: Never.self) { try SafetyPolicy(home: home.root).validate(derivedData) }
    }

    @Test func trashEntriesAreDeletedPermanently() async throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        try home.makeFile(".Trash/Old Project.zip", bytes: 300_000)
        try home.makeFile(".Trash/Invoices 2024/january.pdf", bytes: 50_000)
        try home.makeFile(".Trash/.DS_Store", bytes: 6_148)

        let items = await DiskScanner.scan(.trash, in: context(home))

        #expect(Set(items.map(\.name)) == ["Old Project.zip", "Invoices 2024"])
        let policy = SafetyPolicy(home: home.root)
        for item in items {
            #expect(item.category == .trash)
            #expect(item.action == .delete)
            #expect(item.selectedByDefault)
            #expect(throws: Never.self, "\(item.name)") { try policy.validate(item) }
        }
    }
}

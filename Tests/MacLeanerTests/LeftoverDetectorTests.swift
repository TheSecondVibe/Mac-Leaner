import Testing
import Foundation
@testable import MacLeaner

@Suite("LeftoverDetector")
struct LeftoverDetectorTests {
    private static let installed = LeftoverDetector.InstalledApps(
        bundleIDs: ["com.hnc.discord"], names: ["discord", "googlechrome"]
    )
    private static let leftoverName = "ZzUninstalledTestAppXyz"

    // MARK: Matching

    @Test(arguments: ["Animoji", "MobileSync", "com.apple.foo", "CloudDocs"])
    func recognizesSystemFolders(_ folder: String) {
        #expect(LeftoverDetector.isSystemFolder(folder))
    }

    @Test(arguments: ["Discord", "ZzUninstalledTestAppXyz"])
    func thirdPartyFoldersAreNotSystemFolders(_ folder: String) {
        #expect(!LeftoverDetector.isSystemFolder(folder))
    }

    @Test func normalizeKeepsLowercasedLettersAndDigits() {
        #expect(LeftoverDetector.normalize("Google Chrome") == "googlechrome")
    }

    @Test(arguments: ["discord", "Google", "com.hnc.Discord"])
    func matchesInstalledApps(_ folder: String) {
        #expect(LeftoverDetector.isInstalled(folder: folder, installed: Self.installed))
    }

    @Test func doesNotMatchRemovedApps() {
        #expect(!LeftoverDetector.isInstalled(folder: "SomeRemovedApp", installed: Self.installed))
    }

    // MARK: Scanning a temporary home

    /// A 2 MB support folder whose files and folders were last modified at `date`.
    private func makeSupportFolder(in home: TemporaryHome, modified date: Date) throws -> URL {
        let base = "Library/Application Support/\(Self.leftoverName)"
        let files = [
            try home.makeFile("\(base)/data.bin", bytes: 1_000_000),
            try home.makeFile("\(base)/Cache/blob.bin", bytes: 1_000_000),
        ]
        let folder = home.url(base)
        for url in files + [folder.appendingPathComponent("Cache"), folder] {
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        }
        return folder
    }

    private func context(_ home: TemporaryHome, now: Date) -> ScanContext {
        ScanContext(
            home: home.root, largeFileThreshold: .max, leftoverIdleDays: 90,
            hasFullDiskAccess: false, ownBundleID: nil, now: now
        )
    }

    @Test func reportsAnOldFolderOfAnUninstalledApp() async throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let now = Date()
        let folder = try makeSupportFolder(in: home, modified: now.addingTimeInterval(-365 * 86_400))

        let items = await LeftoverDetector.scan(context(home, now: now))

        #expect(items.map(\.name) == [Self.leftoverName])
        let item = try #require(items.first)
        #expect(item.url.lastPathComponent == folder.lastPathComponent)
        #expect(item.category == .leftovers)
        #expect(item.action == .moveToTrash)
        #expect(item.selectedByDefault == false)
        #expect(item.safety == .review)
        #expect(item.size >= 2_000_000)

        // Validation only: running the engine would move it into the real Trash.
        let policy = SafetyPolicy(home: home.root)
        #expect(throws: Never.self) { try policy.validate(item) }
        var permanent = item
        permanent.action = .delete
        #expect(throws: SafetyPolicy.Violation.permanentDeletionNotAllowed) { try policy.validate(permanent) }
    }

    @Test func ignoresARecentlyUsedFolder() async throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let now = Date()
        _ = try makeSupportFolder(in: home, modified: now.addingTimeInterval(-3_600))

        let items = await LeftoverDetector.scan(context(home, now: now))

        #expect(items.isEmpty)
    }
}

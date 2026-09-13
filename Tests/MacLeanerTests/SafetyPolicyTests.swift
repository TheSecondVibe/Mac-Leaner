import Testing
import Foundation
@testable import MacLeaner

// MARK: - Shared test support
//
// Used by every suite in this target. Tests only ever work inside a
// TemporaryHome: nothing here reads, scans or changes the real home folder.

/// A throwaway folder that stands in for the user's home folder.
///
/// It lives in `FileManager.default.temporaryDirectory`, i.e. under
/// /var/folders, which is itself a symlink to /private/var/folders.
struct TemporaryHome {
    private static let prefix = "MacLeanerTests-"

    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(Self.prefix + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func url(_ relativePath: String) -> URL {
        root.appendingPathComponent(relativePath)
    }

    /// The URL of `relativePath`, with its parent folder created but not the item itself.
    func urlWithParent(_ relativePath: String) throws -> URL {
        let item = url(relativePath)
        try FileManager.default.createDirectory(
            at: item.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        return item
    }

    @discardableResult
    func makeDirectory(_ relativePath: String) throws -> URL {
        let folder = url(relativePath)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Writes `bytes` of non-zero data, creating parent folders as needed.
    @discardableResult
    func makeFile(_ relativePath: String, bytes: Int) throws -> URL {
        let file = try urlWithParent(relativePath)
        try Data(repeating: 0xA5, count: bytes).write(to: file)
        return file
    }

    /// Deletes the folder. Refuses anything that isn't a folder this type created.
    func remove() {
        guard root.lastPathComponent.hasPrefix(Self.prefix),
              root.path.hasPrefix(FileManager.default.temporaryDirectory.path) else { return }
        try? FileManager.default.removeItem(at: root)
    }
}

/// An item as a scanner would hand it over. Only the fields the policy and engine read matter.
func makeItem(
    _ url: URL, _ category: CleanCategory, _ action: CleanAction, size: Int64 = 0
) -> CleanableItem {
    CleanableItem(
        url: url, name: url.lastPathComponent, detail: "", category: category, size: size,
        isDirectory: true, safety: .safe, action: action, selectedByDefault: false
    )
}

/// The fully resolved path, e.g. /private/var/folders/... for /var/folders/...
func physicalPath(of url: URL) throws -> String {
    let resolved = try #require(realpath(url.path, nil))
    defer { free(resolved) }
    return String(cString: resolved)
}

/// A path relative to the temporary home, cleaned with `action` as part of `category`.
struct PolicyCase: Sendable, CustomTestStringConvertible {
    let path: String
    let action: CleanAction
    let category: CleanCategory

    init(_ path: String, _ action: CleanAction, _ category: CleanCategory) {
        self.path = path
        self.action = action
        self.category = category
    }

    var testDescription: String { "\(action.rawValue) ~/\(path) (\(category.rawValue))" }
}

private typealias Violation = SafetyPolicy.Violation

// MARK: - SafetyPolicy

@Suite("SafetyPolicy")
struct SafetyPolicyTests {

    // MARK: Allowed

    @Test func allowsEmptyingDerivedData() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let derivedData = try home.makeDirectory("Library/Developer/Xcode/DerivedData")

        #expect(throws: Never.self) {
            try SafetyPolicy(home: home.root).validate(makeItem(derivedData, .developer, .emptyContents))
        }
    }

    @Test func allowsDeletingAnAppCacheFolder() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let cache = try home.makeDirectory("Library/Caches/com.example.app")

        #expect(throws: Never.self) {
            try SafetyPolicy(home: home.root).validate(makeItem(cache, .appCaches, .delete))
        }
    }

    @Test func permanentRootsCanBeEmptiedButNotDeleted() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let derivedData = try home.makeDirectory("Library/Developer/Xcode/DerivedData")
        let project = try home.makeDirectory("Library/Developer/Xcode/DerivedData/MyApp-abcdef")
        let policy = SafetyPolicy(home: home.root)

        #expect(throws: Never.self) { try policy.validate(makeItem(project, .developer, .delete)) }
        #expect(throws: Violation.permanentDeletionNotAllowed) {
            try policy.validate(makeItem(derivedData, .developer, .delete))
        }
    }

    @Test func allowsTrashingALargeDownload() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let iso = try home.makeFile("Downloads/big.iso", bytes: 1)

        #expect(throws: Never.self) {
            try SafetyPolicy(home: home.root).validate(makeItem(iso, .largeFiles, .moveToTrash))
        }
    }

    @Test func onlyMacOSInstallersMayLeaveHomeAndOnlyToTheTrash() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let policy = SafetyPolicy(home: home.root)
        let installer = URL(fileURLWithPath: "/Applications/Install macOS Tahoe.app")
        let safari = URL(fileURLWithPath: "/Applications/Safari.app")

        #expect(throws: Never.self) { try policy.validate(makeItem(installer, .systemData, .moveToTrash)) }
        #expect(throws: Violation.outsideHomeFolder) {
            try policy.validate(makeItem(installer, .systemData, .delete))
        }
        #expect(throws: Violation.outsideHomeFolder) {
            try policy.validate(makeItem(safari, .systemData, .moveToTrash))
        }
    }

    // MARK: Rejected

    @Test func rejectsPathsOutsideHome() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let elsewhere = try TemporaryHome()
        defer { elsewhere.remove() }
        // A sibling whose name merely starts with the home folder's name.
        let lookalike = URL(fileURLWithPath: home.root.path + "-lookalike", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: lookalike) }
        let lookalikeCache = lookalike.appendingPathComponent("Library/Caches/com.example.app")
        try FileManager.default.createDirectory(at: lookalikeCache, withIntermediateDirectories: true)
        let foreignCache = try elsewhere.makeDirectory("Library/Caches/com.example.app")
        let systemCache = URL(fileURLWithPath: "/Library/Caches/com.example.app")
        let policy = SafetyPolicy(home: home.root)

        for url in [foreignCache, lookalikeCache, systemCache] {
            #expect(throws: Violation.outsideHomeFolder, "\(url.path)") {
                try policy.validate(makeItem(url, .appCaches, .delete))
            }
        }
    }

    @Test func rejectsHomeItself() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let policy = SafetyPolicy(home: home.root)

        for action in [CleanAction.delete, .emptyContents, .moveToTrash] {
            #expect(throws: Violation.self, "\(action)") {
                try policy.validate(makeItem(home.root, .appCaches, action))
            }
        }
    }

    @Test(arguments: [
        PolicyCase("Documents", .moveToTrash, .largeFiles),
        PolicyCase("Library/Caches", .delete, .appCaches),
        PolicyCase("Library/Caches", .emptyContents, .appCaches),
        PolicyCase("Library/Logs", .emptyContents, .logs),
        PolicyCase("Library/Developer/Xcode", .emptyContents, .developer),
        PolicyCase("Library/Application Support", .moveToTrash, .leftovers),
        PolicyCase(".Trash", .emptyContents, .trash),
    ])
    func neverRemovesProtectedFoldersThemselves(_ policyCase: PolicyCase) throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let folder = try home.makeDirectory(policyCase.path)

        #expect(throws: Violation.protectedLocation) {
            try SafetyPolicy(home: home.root).validate(makeItem(folder, policyCase.category, policyCase.action))
        }
    }

    @Test(arguments: [
        "Library/Keychains",
        "Library/Keychains/login.keychain-db",
        "Library/Mobile Documents/com~apple~CloudDocs/Notes.txt",
        "Library/CloudStorage/Dropbox/Taxes.pdf",
        ".ssh",
        ".ssh/id_ed25519",
    ])
    func rejectsAnythingInsideProtectedTrees(_ path: String) throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let url = try home.urlWithParent(path)
        let policy = SafetyPolicy(home: home.root)

        #expect(throws: Violation.protectedLocation) { try policy.validate(makeItem(url, .leftovers, .moveToTrash)) }
        #expect(throws: Violation.protectedLocation) { try policy.validate(makeItem(url, .appCaches, .delete)) }
    }

    @Test func rejectsDotDotTraversal() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        try home.makeDirectory("Library/Caches")
        try home.makeDirectory("Library/Keychains")
        try home.makeDirectory("Documents")
        let policy = SafetyPolicy(home: home.root)

        let intoDocuments = home.url("Library/Caches/../../Documents/x")
        let intoKeychains = home.url("Library/Caches/../Keychains/login.keychain-db")
        let outOfHome = home.url("Library/Caches/../../../elsewhere/x")
        // The URL really carries the traversal; it isn't collapsed on construction.
        #expect(intoDocuments.path.contains("/../"))

        #expect(throws: Violation.self) { try policy.validate(makeItem(intoDocuments, .appCaches, .delete)) }
        #expect(throws: Violation.self) { try policy.validate(makeItem(intoDocuments, .developer, .emptyContents)) }
        #expect(throws: Violation.self) { try policy.validate(makeItem(intoKeychains, .leftovers, .moveToTrash)) }
        #expect(throws: Violation.self) { try policy.validate(makeItem(outOfHome, .appCaches, .delete)) }
    }

    /// On disk, `link/..` is the parent of the link's *target*, not the folder
    /// holding the link, so collapsing `..` as text points the check at the wrong file.
    @Test func rejectsDotDotThroughASymlinkedFolder() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let outside = try TemporaryHome()
        defer { outside.remove() }
        try home.makeDirectory("Library/Caches")
        let target = try outside.makeDirectory("Target")
        let victim = try outside.makeFile("victim.txt", bytes: 16)
        try FileManager.default.createSymbolicLink(at: home.url("Library/Caches/link"), withDestinationURL: target)

        let sneaky = home.url("Library/Caches/link/../victim.txt")
        // The kernel resolves the path to the file outside home...
        #expect(FileManager.default.fileExists(atPath: sneaky.path))
        #expect(!FileManager.default.fileExists(atPath: home.url("Library/Caches/victim.txt").path))
        #expect(try physicalPath(of: sneaky) == physicalPath(of: victim))

        // ...so the policy must not approve deleting it.
        #expect(throws: Violation.self) {
            try SafetyPolicy(home: home.root).validate(makeItem(sneaky, .appCaches, .delete))
        }
    }

    /// When the last component can't be resolved (here a dangling link),
    /// `standardizedFileURL` falls back to collapsing `..` as text, so the policy
    /// checks ~/Library/Caches/dangling while the kernel reaches the link outside home.
    @Test func rejectsDotDotThroughASymlinkedFolderToADanglingLink() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let outside = try TemporaryHome()
        defer { outside.remove() }
        try home.makeDirectory("Library/Caches")
        let target = try outside.makeDirectory("Target")
        try FileManager.default.createSymbolicLink(at: home.url("Library/Caches/link"), withDestinationURL: target)
        try FileManager.default.createSymbolicLink(
            atPath: outside.url("dangling").path, withDestinationPath: "/nonexistent/target"
        )

        let sneaky = home.url("Library/Caches/link/../dangling")
        // On disk the path names the link outside home, which the engine would remove.
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: sneaky.path)) == "/nonexistent/target")

        #expect(throws: Violation.invalidPath) {
            try SafetyPolicy(home: home.root).validate(makeItem(sneaky, .appCaches, .delete))
        }
    }

    @Test func rejectsEscapesThroughASymlinkedParent() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let outside = try TemporaryHome()
        defer { outside.remove() }
        try home.makeDirectory("Library/Caches")
        let target = try outside.makeDirectory("Target")
        try outside.makeFile("Target/file", bytes: 16)
        let link = home.url("Library/Caches/link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let escaped = home.url("Library/Caches/link/file")
        let policy = SafetyPolicy(home: home.root)

        #expect(throws: Violation.outsideHomeFolder) { try policy.validate(makeItem(escaped, .appCaches, .delete)) }
        #expect(throws: Violation.outsideHomeFolder) {
            try policy.validate(makeItem(escaped, .largeFiles, .moveToTrash))
        }
        // Removing the link itself only removes the link, so that stays allowed.
        #expect(throws: Never.self) { try policy.validate(makeItem(link, .appCaches, .delete)) }
    }

    @Test(arguments: [
        PolicyCase("Downloads/big.iso", .delete, .largeFiles),
        PolicyCase("Library/Caches/big.bin", .delete, .largeFiles),
        PolicyCase("Library/Application Support/OldApp", .delete, .leftovers),
        PolicyCase("Library/Logs/OldApp", .emptyContents, .leftovers),
    ])
    func reviewCategoriesCanOnlyGoToTheTrash(_ policyCase: PolicyCase) throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let url = try home.urlWithParent(policyCase.path)

        #expect(throws: Violation.permanentDeletionNotAllowed) {
            try SafetyPolicy(home: home.root).validate(makeItem(url, policyCase.category, policyCase.action))
        }
    }

    @Test(arguments: [
        PolicyCase("Documents/report.pdf", .delete, .appCaches),
        PolicyCase("Library/Application Support/SomeApp/data.db", .delete, .systemData),
        // The parent of a known permanent location isn't one itself.
        PolicyCase("Library/Application Support/Claude", .emptyContents, .systemData),
        // Archives are listed, but only for the Trash.
        PolicyCase("Library/Developer/Xcode/Archives/App.xcarchive", .delete, .developer),
        // Shares a prefix with Library/Caches but isn't inside it.
        PolicyCase("Library/CachesBackup/file.bin", .delete, .appCaches),
    ])
    func rejectsPermanentActionsOutsideDeletionRoots(_ policyCase: PolicyCase) throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let url = try home.urlWithParent(policyCase.path)

        #expect(throws: Violation.permanentDeletionNotAllowed) {
            try SafetyPolicy(home: home.root).validate(makeItem(url, policyCase.category, policyCase.action))
        }
    }

    @Test func rejectsExcludedPathsAndTheirChildren() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let kept = try home.makeDirectory("Library/Caches/com.example.keep")
        try home.makeDirectory("Library/Caches/com.example.keep/sub")
        let neighbour = try home.makeDirectory("Library/Caches/com.example.keeper")
        let installer = "/Applications/Install macOS Tahoe.app"
        let policy = SafetyPolicy(home: home.root, excludedPaths: [kept.path, installer])

        #expect(throws: Violation.excludedByUser) { try policy.validate(makeItem(kept, .appCaches, .emptyContents)) }
        #expect(throws: Violation.excludedByUser) {
            try policy.validate(makeItem(kept.appendingPathComponent("sub/data.bin"), .appCaches, .delete))
        }
        #expect(throws: Violation.excludedByUser) {
            try policy.validate(makeItem(URL(fileURLWithPath: installer), .systemData, .moveToTrash))
        }
        // Only whole path components match: a folder that starts with the same name isn't excluded.
        #expect(throws: Never.self) { try policy.validate(makeItem(neighbour, .appCaches, .delete)) }
    }

    @Test func rejectsInformationalItems() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let cache = try home.makeDirectory("Library/Caches/com.example.app")

        #expect(throws: Violation.informational) {
            try SafetyPolicy(home: home.root).validate(makeItem(cache, .systemData, .none))
        }
    }

    // MARK: Canonicalization

    /// The temporary directory is /var/folders/..., and /var is a symlink to
    /// /private/var. Both spellings must be treated as the same home folder.
    @Test func canonicalizesHomeUnderTheTemporaryDirectory() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        try home.makeDirectory("Library/Caches/com.example.app")
        let physicalRoot = URL(fileURLWithPath: try physicalPath(of: home.root), isDirectory: true)
        let spellings = [home.root, physicalRoot]

        for policyHome in spellings {
            let policy = SafetyPolicy(home: policyHome)
            for itemHome in spellings {
                let context: Comment = "home \(policyHome.path), item under \(itemHome.path)"
                let cache = itemHome.appendingPathComponent("Library/Caches/com.example.app")
                let gone = itemHome.appendingPathComponent("Library/Caches/com.example.gone")
                let caches = itemHome.appendingPathComponent("Library/Caches")

                #expect(throws: Never.self, context) { try policy.validate(makeItem(cache, .appCaches, .delete)) }
                #expect(throws: Never.self, context) { try policy.validate(makeItem(gone, .appCaches, .delete)) }
                #expect(throws: Violation.protectedLocation, context) {
                    try policy.validate(makeItem(caches, .appCaches, .delete))
                }
            }
        }
    }
}

// MARK: - KnownLocations

@Suite("KnownLocations")
struct KnownLocationsTests {
    @Test func everyEntryPathIsUnique() {
        let paths = KnownLocations.all.map(\.path)
        let duplicates = Dictionary(grouping: paths, by: { $0 }).filter { $0.value.count > 1 }.keys
        #expect(duplicates.isEmpty, "Listed more than once: \(duplicates.sorted())")
    }

    @Test func entryPathsAreRelativeAndNormalized() {
        for path in KnownLocations.all.map(\.path) {
            #expect(!path.isEmpty && !path.hasPrefix("/") && !path.hasSuffix("/"), "\(path)")
            #expect(!path.split(separator: "/").contains { $0 == ".." || $0 == "." }, "\(path)")
        }
    }

    @Test func permanentPathsStayClearOfProtectedLocations() {
        #expect(!KnownLocations.permanentPaths.isEmpty)
        let protectedLocations = SafetyPolicy.protectedTrees + SafetyPolicy.protectedFolders.filter { !$0.isEmpty }

        for path in KnownLocations.permanentPaths {
            #expect(!SafetyPolicy.protectedFolders.contains(path), "\(path) is a protected folder")
            for tree in SafetyPolicy.protectedTrees {
                #expect(path != tree && !path.hasPrefix(tree + "/"), "\(path) lies inside protected tree \(tree)")
            }
            // Emptying a permanent location must not reach into protected data either.
            for protected in protectedLocations {
                #expect(!protected.hasPrefix(path + "/"), "\(path) contains protected location \(protected)")
            }
        }
    }

    @Test func claimedCacheFoldersIncludeHomebrewAndSwiftPM() {
        #expect(KnownLocations.claimedCacheFolders.contains("Homebrew"))
        #expect(KnownLocations.claimedCacheFolders.contains("org.swift.swiftpm"))
    }

    /// The scanner lists known locations with exactly these actions and
    /// categories, so the policy has to accept every one of them.
    @Test func policyAcceptsEveryKnownLocation() throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let policy = SafetyPolicy(home: home.root)
        let groups: [([KnownLocations.Entry], CleanCategory)] = [
            (KnownLocations.developer, .developer),
            (KnownLocations.packageCaches, .packageCaches),
            (KnownLocations.appDataCaches, .systemData),
        ]

        for (entries, category) in groups {
            for entry in entries {
                let url = try home.makeDirectory(entry.path)
                #expect(throws: Never.self, "\(entry.name)") {
                    try policy.validate(makeItem(url, category, entry.action))
                }
            }
        }
    }
}

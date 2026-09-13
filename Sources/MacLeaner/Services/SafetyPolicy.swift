import Foundation

/// The last line of defence: every item is checked here immediately before it is
/// touched. Scanners should never produce an item this rejects; the policy exists
/// so that a scanner bug can't turn into deleting the wrong thing.
///
/// Rules:
/// 1. Only paths inside the home folder are touched (plus macOS installer apps,
///    which may only be moved to the Trash).
/// 2. Top-level folders such as `~/Documents` or `~/Library/Caches` are never
///    removed themselves, and private data (Keychains, iCloud Drive, Mail,
///    Messages, cloud storage, SSH keys, ...) is never touched at all.
/// 3. Permanent deletion is only allowed inside known cache, log and build-product
///    locations. Everything else can only be moved to the Trash.
/// 4. Locations the user excluded in Settings are never touched.
struct SafetyPolicy: Sendable {
    enum Violation: LocalizedError, Equatable {
        case informational
        case invalidPath
        case outsideHomeFolder
        case protectedLocation
        case excludedByUser
        case permanentDeletionNotAllowed

        var errorDescription: String? {
            switch self {
            case .informational: "This item can't be cleaned from Mac-Leaner."
            case .invalidPath: "The path isn't a valid absolute file path."
            case .outsideHomeFolder: "Mac-Leaner only cleans inside your home folder."
            case .protectedLocation: "This location is protected and is never cleaned."
            case .excludedByUser: "You excluded this location in Settings."
            case .permanentDeletionNotAllowed: "Only caches, logs and build products can be deleted permanently."
            }
        }
    }

    /// Relative to the home folder. These folders are never removed themselves.
    static let protectedFolders: Set<String> = [
        "", "Library", "Library/Application Support", "Library/Caches", "Library/Containers",
        "Library/Group Containers", "Library/Developer", "Library/Developer/Xcode", "Library/Logs",
        "Library/Preferences", "Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures",
        "Public", "Applications", ".Trash", "Parallels", "Virtual Machines.localized",
    ]

    /// Relative to the home folder. Nothing inside these is ever touched.
    static let protectedTrees: [String] = [
        "Library/Keychains", "Library/Mobile Documents", "Library/CloudStorage", "Library/Mail",
        "Library/Messages", "Library/Accounts", "Library/Cookies", "Library/Safari", "Library/Photos",
        "Library/Calendars", "Library/Preferences", "Library/Application Support/MobileSync",
        "Library/Application Support/AddressBook", "Library/Application Support/CallHistoryDB",
        "Library/Application Support/com.apple.TCC", ".ssh", ".gnupg", ".config",
    ]

    /// Relative to the home folder. Permanent deletion is only allowed inside these.
    static let permanentDeletionRoots: [String] = ["Library/Caches", "Library/Logs", ".Trash"]
        + KnownLocations.permanentPaths

    let home: URL
    private let homePath: String
    private let excludedPaths: [String]

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser, excludedPaths: [String] = []) {
        self.home = home
        homePath = Self.canonical(home.standardizedFileURL.path)
        self.excludedPaths = excludedPaths.map { Self.canonical(URL(fileURLWithPath: $0).standardizedFileURL.path) }
    }

    /// Checks an item and returns the canonical location to act on. Callers must
    /// use the returned URL rather than `item.url`, so the path that was checked
    /// is exactly the path that gets touched.
    @discardableResult
    func validate(_ item: CleanableItem) throws -> URL {
        guard item.action != .none else { throw Violation.informational }
        let path = try canonicalPath(of: item.url)
        let target = URL(fileURLWithPath: path)

        if excludedPaths.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            throw Violation.excludedByUser
        }
        if item.action == .moveToTrash, Self.isMacOSInstaller(path) { return target }

        guard path.hasPrefix(homePath + "/") else { throw Violation.outsideHomeFolder }
        let relative = String(path.dropFirst(homePath.count + 1))

        if Self.protectedFolders.contains(relative) ||
            Self.protectedTrees.contains(where: { relative == $0 || relative.hasPrefix($0 + "/") }) {
            throw Violation.protectedLocation
        }

        if item.action.isPermanent {
            guard !(item.category == .largeFiles || item.category == .leftovers) else {
                throw Violation.permanentDeletionNotAllowed
            }
            let allowed = Self.permanentDeletionRoots.contains { root in
                relative.hasPrefix(root + "/") || (item.action == .emptyContents && relative == root)
            }
            guard allowed else { throw Violation.permanentDeletionNotAllowed }
        }
        return target
    }

    /// Resolves symlinks in the parent chain so a linked folder can't redirect a
    /// deletion elsewhere. The item itself isn't resolved: removing a link only
    /// removes the link.
    private func canonicalPath(of url: URL) throws -> String {
        // Reject ".." outright. Standardizing can collapse it textually when part of
        // the path doesn't exist, while the kernel would resolve it through a symlink.
        guard url.isFileURL, url.path.hasPrefix("/"), !url.pathComponents.contains("..") else {
            throw Violation.invalidPath
        }
        let standardized = url.standardizedFileURL
        guard standardized.lastPathComponent != "/" else { throw Violation.invalidPath }
        let parent = Self.canonical(standardized.deletingLastPathComponent().path)
        return (parent == "/" ? "" : parent) + "/" + standardized.lastPathComponent
    }

    private static func canonical(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }

    static func isMacOSInstaller(_ path: String) -> Bool {
        let parts = path.split(separator: "/")
        return parts.count == 2 && parts[0] == "Applications"
            && parts[1].hasPrefix("Install macOS") && parts[1].hasSuffix(".app")
    }
}

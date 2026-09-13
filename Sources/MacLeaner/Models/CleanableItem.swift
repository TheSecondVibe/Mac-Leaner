import Foundation

/// How much judgment an item needs before it is removed.
enum Safety: String, Sendable {
    /// Regenerates automatically; removing it only costs a re-download or rebuild.
    case safe
    /// The user's own data or something expensive to recreate.
    case review
    /// Can't be cleaned from Mac-Leaner; the item explains how to reclaim it.
    case manual
}

/// What cleaning an item does. Scanners decide this explicitly for every item;
/// the engine never infers it.
enum CleanAction: String, Sendable {
    /// Permanently remove the item.
    case delete
    /// Permanently remove everything inside the folder but keep the folder.
    case emptyContents
    /// Move the item to the Trash, where it can be restored.
    case moveToTrash
    /// Informational only.
    case none

    var isPermanent: Bool { self == .delete || self == .emptyContents }
}

struct CleanableItem: Identifiable, Hashable, Sendable {
    let url: URL
    var name: String
    var detail: String
    var category: CleanCategory
    /// Bytes actually allocated on disk (sparse files count what they occupy).
    var size: Int64
    var fileCount: Int = 1
    /// Newest modification date of anything inside the item.
    var lastModified: Date?
    var isDirectory: Bool
    var safety: Safety
    var action: CleanAction
    var selectedByDefault: Bool
    /// App that owns this data and should be quit before cleaning it.
    var ownerBundleID: String? = nil
    /// Optional grouping inside a category (used by System Data).
    var section: String? = nil
    /// For manual items: how to reclaim the space.
    var hint: String? = nil

    /// Paths are stable across rescans, so selections survive them.
    var id: String { url.path }
    var isCleanable: Bool { action != .none }
    var sortDate: Date { lastModified ?? .distantPast }
}

extension Int64 {
    /// Finder-style size, e.g. "12.4 GB".
    var byteString: String {
        self <= 0 ? "0 KB" : formatted(.byteCount(style: .file))
    }

    /// The size split into number and unit, for large typographic displays.
    var byteParts: (value: String, unit: String) {
        let text = byteString
        guard let space = text.lastIndex(where: { $0 == " " || $0 == "\u{00A0}" }) else { return (text, "") }
        return (String(text[..<space]), String(text[text.index(after: space)...]))
    }
}

import Foundation

/// The items a user is about to clean, shown in the review sheet first.
struct ReviewRequest: Identifiable {
    let id = UUID()
    let items: [CleanableItem]

    var permanent: [CleanableItem] { items.filter { $0.action.isPermanent } }
    var trashed: [CleanableItem] { items.filter { $0.action == .moveToTrash } }
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}

/// What actually happened during a clean. Nothing here is estimated from the
/// request: failures are recorded, and partially removed folders are re-measured.
struct CleanReport: Identifiable, Sendable {
    let id = UUID()

    struct Failure: Identifiable, Sendable {
        let id = UUID()
        let name: String
        let path: String
        let reason: String
    }

    /// Permanently removed.
    var freedBytes: Int64 = 0
    /// Moved to the Trash; reclaimed only once the Trash is emptied.
    var trashedBytes: Int64 = 0
    /// Items that were cleaned completely.
    var cleanedIDs: [String] = []
    /// Where trashed items landed, so they aren't preselected for permanent deletion later.
    var trashedPaths: [String] = []
    var failures: [Failure] = []
    var availableBefore: Int64 = 0
    var availableAfter: Int64 = 0

    var cleanedCount: Int { cleanedIDs.count }
    var availableDelta: Int64 { availableAfter - availableBefore }
}

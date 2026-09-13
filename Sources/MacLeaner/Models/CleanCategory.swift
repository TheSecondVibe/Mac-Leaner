import SwiftUI

/// Everything Mac-Leaner can find, grouped the way it is presented.
///
/// Cleanup categories hold data that regenerates on its own, so their safe items
/// start selected. Review categories hold data only the user can judge, so
/// nothing in them is ever preselected.
enum CleanCategory: String, CaseIterable, Identifiable, Sendable {
    case developer
    case packageCaches
    case appCaches
    case logs
    case trash
    case largeFiles
    case leftovers
    case systemData

    var id: String { rawValue }

    static let cleanup: [CleanCategory] = [.developer, .packageCaches, .appCaches, .logs, .trash]
    static let review: [CleanCategory] = [.largeFiles, .leftovers, .systemData]

    var isReview: Bool { Self.review.contains(self) }

    var title: String {
        switch self {
        case .developer: "Developer"
        case .packageCaches: "Package Caches"
        case .appCaches: "App Caches"
        case .logs: "Logs & Reports"
        case .trash: "Trash"
        case .largeFiles: "Large Files"
        case .leftovers: "App Leftovers"
        case .systemData: "System Data"
        }
    }

    var symbol: String {
        switch self {
        case .developer: "hammer.fill"
        case .packageCaches: "shippingbox.fill"
        case .appCaches: "square.stack.3d.up.fill"
        case .logs: "doc.text.magnifyingglass"
        case .trash: "trash.fill"
        case .largeFiles: "doc.on.doc.fill"
        case .leftovers: "puzzlepiece.extension.fill"
        case .systemData: "externaldrive.fill"
        }
    }

    var tint: Color {
        switch self {
        case .developer: .blue
        case .packageCaches: .purple
        case .appCaches: .teal
        case .logs: .orange
        case .trash: .gray
        case .largeFiles: .pink
        case .leftovers: .indigo
        case .systemData: .cyan
        }
    }

    var summary: String {
        switch self {
        case .developer:
            "Xcode build products, device symbols, previews and simulator caches."
        case .packageCaches:
            "Downloads cached by Homebrew, npm, Yarn, pip, Cargo, Gradle and other tools."
        case .appCaches:
            "Caches that apps rebuild automatically, such as browser and media caches."
        case .logs:
            "Diagnostic logs and crash reports written by apps."
        case .trash:
            "Files waiting in your Trash."
        case .largeFiles:
            "Big files in Downloads, Desktop, Documents and Movies."
        case .leftovers:
            "Support folders from apps that no longer seem to be installed."
        case .systemData:
            "Virtual machines, app data and simulators that macOS counts as System Data."
        }
    }
}

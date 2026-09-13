import Foundation

/// Realistic sample data for screenshots and UI work (`--demo`).
/// Demo mode never reads or changes anything on disk.
enum DemoData {
    static let home = URL(fileURLWithPath: "/Users/demo")

    static let metrics = SystemMetrics(
        totalDisk: 994_662_584_320,
        availableDisk: 164_800_000_000,
        totalMemory: 34_359_738_368,
        usedMemory: 21_700_000_000
    )

    private static let gb: Int64 = 1_000_000_000
    private static let mb: Int64 = 1_000_000

    static func items(for category: CleanCategory) -> [CleanableItem] {
        let items: [CleanableItem]
        switch category {
        case .developer:
            items = [
                make(.developer, "Xcode DerivedData", "Library/Developer/Xcode/DerivedData", 18_400 * mb, "Build products and indexes. Xcode rebuilds them when needed.", owner: "com.apple.dt.Xcode"),
                make(.developer, "iOS Device Support", "Library/Developer/Xcode/iOS DeviceSupport", 9_700 * mb, "Debug symbols copied from iPhones and iPads."),
                make(.developer, "Simulator Caches", "Library/Developer/CoreSimulator/Caches", 3_100 * mb, "Runtime caches for simulators. Rebuilt automatically."),
                make(.developer, "SwiftUI Previews", "Library/Developer/Xcode/UserData/Previews", 1_600 * mb, "Simulators and caches used by Xcode previews."),
                make(.developer, "Swift Package Manager", "Library/Caches/org.swift.swiftpm", 820 * mb, "Cached package repositories."),
                make(.developer, "Xcode Archives", "Library/Developer/Xcode/Archives", 6_200 * mb, "Archived app builds and their dSYMs.", safety: .review, action: .moveToTrash, selected: false),
            ]
        case .packageCaches:
            items = [
                make(.packageCaches, "Gradle", ".gradle/caches", 4_800 * mb, "Dependencies and build caches."),
                make(.packageCaches, "Homebrew", "Library/Caches/Homebrew", 3_400 * mb, "Downloaded bottles and installers."),
                make(.packageCaches, "npm", ".npm/_cacache", 2_100 * mb, "Package tarballs cached by npm."),
                make(.packageCaches, "Cargo", ".cargo/registry/cache", 1_200 * mb, "Downloaded Rust crate archives."),
                make(.packageCaches, "Yarn", "Library/Caches/Yarn", 950 * mb, "Package cache for Yarn 1."),
                make(.packageCaches, "pip", "Library/Caches/pip", 640 * mb, "Python wheels and downloads."),
                make(.packageCaches, "Maven", ".m2/repository", 1_100 * mb, "Downloaded Java libraries.", safety: .review, selected: false),
            ]
        case .appCaches:
            items = [
                make(.appCaches, "Spotify", "Library/Caches/com.spotify.client", 2_400 * mb, "~/Library/Caches/com.spotify.client", owner: "com.spotify.client"),
                make(.appCaches, "Google Chrome", "Library/Caches/Google", 1_900 * mb, "~/Library/Caches/Google", owner: "com.google.Chrome"),
                make(.appCaches, "Microsoft Edge", "Library/Caches/Microsoft Edge", 1_100 * mb, "~/Library/Caches/Microsoft Edge"),
                make(.appCaches, "Firefox", "Library/Caches/Firefox", 890 * mb, "~/Library/Caches/Firefox"),
                make(.appCaches, "Slack", "Library/Caches/com.tinyspeck.slackmacgap", 780 * mb, "~/Library/Caches/com.tinyspeck.slackmacgap", owner: "com.tinyspeck.slackmacgap"),
                make(.appCaches, "Figma", "Library/Caches/com.figma.Desktop", 540 * mb, "~/Library/Caches/com.figma.Desktop"),
                make(.appCaches, "zoom.us", "Library/Caches/us.zoom.xos", 310 * mb, "~/Library/Caches/us.zoom.xos"),
            ]
        case .logs:
            items = [
                make(.logs, "Crash Reports", "Library/Logs/DiagnosticReports", 420 * mb, "~/Library/Logs/DiagnosticReports"),
                make(.logs, "JetBrains", "Library/Logs/JetBrains", 310 * mb, "~/Library/Logs/JetBrains"),
                make(.logs, "Homebrew", "Library/Logs/Homebrew", 88 * mb, "~/Library/Logs/Homebrew"),
            ]
        case .trash:
            items = [
                make(.trash, "Screen Recording 2026-08-02.mov", ".Trash/Screen Recording 2026-08-02.mov", 3_800 * mb, "In the Trash", action: .delete, folder: false),
                make(.trash, "Old Project.zip", ".Trash/Old Project.zip", 1_200 * mb, "In the Trash", action: .delete, folder: false),
                make(.trash, "Invoices 2024", ".Trash/Invoices 2024", 46 * mb, "In the Trash", action: .delete),
            ]
        case .largeFiles:
            items = [
                make(.largeFiles, "Keynote Export.mov", "Movies/Keynote Export.mov", 12_400 * mb, "~/Movies", safety: .review, action: .moveToTrash, selected: false, folder: false, kind: "QuickTime movie", days: 212),
                make(.largeFiles, "Xcode_16.4.xip", "Downloads/Xcode_16.4.xip", 11_200 * mb, "~/Downloads", safety: .review, action: .moveToTrash, selected: false, folder: false, kind: "XIP archive", days: 96),
                make(.largeFiles, "Wedding Film Final.mp4", "Movies/Wedding Film Final.mp4", 6_800 * mb, "~/Movies", safety: .review, action: .moveToTrash, selected: false, folder: false, kind: "MPEG-4 movie", days: 540),
                make(.largeFiles, "ubuntu-24.04-desktop-arm64.iso", "Downloads/ubuntu-24.04-desktop-arm64.iso", 3_100 * mb, "~/Downloads", safety: .review, action: .moveToTrash, selected: false, folder: false, kind: "Disk image", days: 150),
                make(.largeFiles, "Survey Results.csv", "Documents/Research/Survey Results.csv", 1_400 * mb, "~/Documents/Research", safety: .review, action: .moveToTrash, selected: false, folder: false, kind: "CSV document", days: 33),
                make(.largeFiles, "Brand Assets.zip", "Desktop/Brand Assets.zip", 620 * mb, "~/Desktop", safety: .review, action: .moveToTrash, selected: false, folder: false, kind: "ZIP archive", days: 12),
            ]
        case .leftovers:
            items = [
                make(.leftovers, "Unity", "Library/Application Support/Unity", 2_800 * mb, "No installed app matches this folder", safety: .review, action: .moveToTrash, selected: false, days: 410),
                make(.leftovers, "Sketch", "Library/Application Support/com.bohemiancoding.sketch3", 1_300 * mb, "No installed app matches this folder", safety: .review, action: .moveToTrash, selected: false, days: 640),
                make(.leftovers, "Postman", "Library/Application Support/Postman", 380 * mb, "No installed app matches this folder", safety: .review, action: .moveToTrash, selected: false, days: 190),
            ]
        case .systemData:
            items = [
                make(.systemData, "Windows 11", "Library/Containers/com.utmapp.UTM/Data/Documents/Windows 11.utm", 64_200 * mb, "UTM virtual machine, including its disks.", safety: .review, action: .moveToTrash, selected: false, owner: "com.utmapp.UTM", section: "Virtual Machines", days: 75),
                make(.systemData, "Ubuntu Server", "Library/Containers/com.utmapp.UTM/Data/Documents/Ubuntu Server.utm", 40_100 * mb, "UTM virtual machine, including its disks.", safety: .review, action: .moveToTrash, selected: false, owner: "com.utmapp.UTM", section: "Virtual Machines", days: 20),
                make(.systemData, "Docker Desktop disk", "Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw", 28_600 * mb, "Images, containers and volumes used by Docker.", safety: .manual, action: .none, selected: false, folder: false, owner: "com.docker.docker", section: "Virtual Machines", hint: "Run “docker system prune” to remove unused images, or lower the disk limit in Docker Desktop → Settings → Resources."),
                make(.systemData, "Claude VM bundles", "Library/Application Support/Claude/vm_bundles", 8_900 * mb, "Sandbox images downloaded by the Claude app. Downloaded again when needed.", selected: false, owner: "com.anthropic.claudefordesktop", section: "App Data"),
                make(.systemData, "Chrome on-device AI model", "Library/Application Support/Google/Chrome/OptGuideOnDeviceModel", 4_000 * mb, "Chrome's local AI model. Downloaded again if the feature is used.", selected: false, owner: "com.google.Chrome", section: "App Data"),
                make(.systemData, "Discord cache", "Library/Application Support/discord/Cache", 1_200 * mb, "Cached images, audio and video.", selected: false, owner: "com.hnc.Discord", section: "App Data"),
                make(.systemData, "Simulator runtimes", "/Library/Developer/CoreSimulator/Images", 21_700 * mb, "Installed simulator runtime images.", safety: .manual, action: .none, selected: false, section: "Developer", hint: "Remove runtimes you no longer need in Xcode → Settings → Components."),
                make(.systemData, "Simulator devices", "Library/Developer/CoreSimulator/Devices", 12_400 * mb, "Apps and data inside your simulators.", safety: .manual, action: .none, selected: false, section: "Developer", hint: "Use “Prune unavailable simulators” above, or delete simulators in Xcode → Window → Devices and Simulators."),
                make(.systemData, "Install macOS Tahoe", "/Applications/Install macOS Tahoe.app", 16_900 * mb, "macOS installer. You can download it again from Apple.", safety: .review, action: .moveToTrash, selected: false, section: "macOS"),
            ]
        }
        return items.sorted { $0.size > $1.size }
    }

    /// What a clean of these items would report, without touching anything.
    static func report(for items: [CleanableItem], available: Int64) -> CleanReport {
        var report = CleanReport()
        report.availableBefore = available
        for item in items where item.isCleanable {
            if item.action == .moveToTrash { report.trashedBytes += item.size } else { report.freedBytes += item.size }
            report.cleanedIDs.append(item.id)
        }
        report.availableAfter = available + report.freedBytes
        return report
    }

    private static func make(
        _ category: CleanCategory, _ name: String, _ path: String, _ size: Int64, _ detail: String,
        safety: Safety = .safe, action: CleanAction = .emptyContents, selected: Bool = true,
        folder: Bool = true, owner: String? = nil, section: String? = nil, kind: String? = nil,
        days: Double = 3, hint: String? = nil
    ) -> CleanableItem {
        let url = path.hasPrefix("/") ? URL(fileURLWithPath: path) : home.appendingPathComponent(path)
        return CleanableItem(
            url: url, name: name, detail: detail, category: category, size: size,
            fileCount: folder ? Int(size / 180_000) + 1 : 1, lastModified: Date.now.addingTimeInterval(-days * 86_400),
            isDirectory: folder, safety: safety, action: action, selectedByDefault: selected && !category.isReview,
            ownerBundleID: owner, section: section ?? kind, hint: hint
        )
    }
}

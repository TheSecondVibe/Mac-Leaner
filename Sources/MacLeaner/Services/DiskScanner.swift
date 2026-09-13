import Foundation

struct ScanContext: Sendable {
    var home: URL
    var largeFileThreshold: Int64
    var leftoverIdleDays: Int
    /// Without Full Disk Access, macOS blocks the Trash and other apps' containers.
    /// Container locations are skipped rather than triggering permission prompts.
    var hasFullDiskAccess: Bool
    var ownBundleID: String?
    var now: Date = .now

    func url(_ relativePath: String) -> URL { home.appendingPathComponent(relativePath) }
}

/// Finds cleanable items. Every category scans independently, so they run in parallel.
enum DiskScanner {
    static func scan(_ category: CleanCategory, in context: ScanContext) async -> [CleanableItem] {
        let items: [CleanableItem]
        switch category {
        case .developer: items = await known(KnownLocations.developer, as: .developer, context)
        case .packageCaches: items = await known(KnownLocations.packageCaches, as: .packageCaches, context)
        case .appCaches: items = await appCaches(context)
        case .logs: items = await logs(context)
        case .trash: items = await trash(context)
        case .largeFiles: items = await largeFiles(context)
        case .leftovers: items = await LeftoverDetector.scan(context)
        case .systemData: items = await systemData(context)
        }
        return items.sorted { $0.size > $1.size }
    }

    // MARK: - Fixed locations

    private static func known(
        _ entries: [KnownLocations.Entry],
        as category: CleanCategory,
        _ context: ScanContext,
        section: String? = nil
    ) async -> [CleanableItem] {
        let present = entries.filter { FileManager.default.fileExists(atPath: context.url($0.path).path) }
        let measured = await present.concurrentMap { entry in (entry, FileSizer.measure(context.url(entry.path))) }
        return measured.compactMap { pair in
            let (entry, usage) = pair
            guard usage.size > 0 else { return nil }
            return CleanableItem(
                url: context.url(entry.path), name: entry.name, detail: entry.detail, category: category,
                size: usage.size, fileCount: usage.fileCount, lastModified: usage.newestModification,
                isDirectory: usage.isDirectory, safety: entry.safety, action: entry.action,
                selectedByDefault: entry.selected && !category.isReview, ownerBundleID: entry.owner, section: section
            )
        }
    }

    // MARK: - Folder contents

    private static func appCaches(_ context: ScanContext) async -> [CleanableItem] {
        let claimed = KnownLocations.claimedCacheFolders
        let candidates = children(of: context.url("Library/Caches"), includeHidden: false).filter {
            let name = $0.lastPathComponent
            return !claimed.contains(name) && !KnownLocations.isSystemCache(name) && name != context.ownBundleID
        }
        let measured = await candidates.concurrentMap { url in (url, FileSizer.measure(url)) }
        return measured.compactMap { pair in
            let (url, usage) = pair
            guard usage.size >= 1_000_000 else { return nil }
            let folder = url.lastPathComponent
            return CleanableItem(
                url: url, name: AppDirectory.displayName(forFolder: folder), detail: "~/Library/Caches/\(folder)",
                category: .appCaches, size: usage.size, fileCount: usage.fileCount,
                lastModified: usage.newestModification, isDirectory: usage.isDirectory, safety: .safe,
                action: usage.isDirectory ? .emptyContents : .delete, selectedByDefault: true,
                ownerBundleID: AppDirectory.looksLikeBundleID(folder) ? folder : nil
            )
        }
    }

    /// Each folder in ~/Library/Logs is its own item, so crash reports aren't counted twice.
    private static func logs(_ context: ScanContext) async -> [CleanableItem] {
        let measured = await children(of: context.url("Library/Logs"), includeHidden: false)
            .concurrentMap { url in (url, FileSizer.measure(url)) }
        return measured.compactMap { pair in
            let (url, usage) = pair
            guard usage.size >= 64_000 else { return nil }
            let folder = url.lastPathComponent
            return CleanableItem(
                url: url, name: folder == "DiagnosticReports" ? "Crash Reports" : folder,
                detail: "~/Library/Logs/\(folder)", category: .logs, size: usage.size, fileCount: usage.fileCount,
                lastModified: usage.newestModification, isDirectory: usage.isDirectory, safety: .safe,
                action: usage.isDirectory ? .emptyContents : .delete, selectedByDefault: true
            )
        }
    }

    private static func trash(_ context: ScanContext) async -> [CleanableItem] {
        let contents = children(of: context.url(".Trash"), includeHidden: true).filter { $0.lastPathComponent != ".DS_Store" }
        let measured = await contents.concurrentMap { url in (url, FileSizer.measure(url)) }
        return measured.map { pair in
            let (url, usage) = pair
            return CleanableItem(
                url: url, name: url.lastPathComponent, detail: "In the Trash", category: .trash,
                size: usage.size, fileCount: usage.fileCount, lastModified: usage.newestModification,
                isDirectory: usage.isDirectory, safety: .safe, action: .delete, selectedByDefault: true
            )
        }
    }

    // MARK: - Large files

    private static func largeFiles(_ context: ScanContext) async -> [CleanableItem] {
        let roots = ["Downloads", "Desktop", "Documents", "Movies"].map(context.url)
        return await roots.concurrentMap { root in largeFiles(in: root, context) }.flatMap { $0 }
    }

    private static func largeFiles(in root: URL, _ context: ScanContext) -> [CleanableItem] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
            .contentModificationDateKey, .localizedTypeDescriptionKey,
        ]
        let keySet = Set(keys)
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in true }
        ) else { return [] }

        var results: [CleanableItem] = []
        var visited = 0
        while let url = enumerator.nextObject() as? URL {
            visited += 1
            if visited.isMultiple(of: 4096), Task.isCancelled { break }
            guard let values = try? url.resourceValues(forKeys: keySet), values.isRegularFile == true else { continue }
            // Allocated size: files evicted to iCloud take no space and aren't listed.
            let size = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            guard size >= context.largeFileThreshold else { continue }
            let folder = url.deletingLastPathComponent().path
                .replacingOccurrences(of: context.home.path, with: "~", options: .anchored)
            results.append(CleanableItem(
                url: url, name: url.lastPathComponent, detail: folder, category: .largeFiles, size: size,
                lastModified: values.contentModificationDate, isDirectory: false, safety: .review,
                action: .moveToTrash, selectedByDefault: false, section: values.localizedTypeDescription
            ))
        }
        return results
    }

    // MARK: - System Data

    private static func systemData(_ context: ScanContext) async -> [CleanableItem] {
        async let machines = virtualMachines(context)
        async let appData = known(KnownLocations.appDataCaches, as: .systemData, context, section: "App Data")
        async let developer = developerData(context)
        async let system = macOSData(context)
        return await machines + appData + developer + system
    }

    private static func virtualMachines(_ context: ScanContext) async -> [CleanableItem] {
        var bundles: [(url: URL, app: String, owner: String)] = []
        if context.hasFullDiskAccess {
            bundles += children(of: context.url("Library/Containers/com.utmapp.UTM/Data/Documents"), includeHidden: false)
                .filter { $0.pathExtension == "utm" }.map { ($0, "UTM", "com.utmapp.UTM") }
        }
        bundles += children(of: context.url("Parallels"), includeHidden: false)
            .filter { $0.pathExtension == "pvm" }.map { ($0, "Parallels Desktop", "com.parallels.desktop.console") }
        bundles += children(of: context.url("Virtual Machines.localized"), includeHidden: false)
            .filter { $0.pathExtension == "vmwarevm" }.map { ($0, "VMware Fusion", "com.vmware.fusion") }

        let measured = await bundles.concurrentMap { bundle in (bundle, FileSizer.measure(bundle.url)) }
        var items: [CleanableItem] = measured.compactMap { pair in
            let (bundle, usage) = pair
            guard usage.size > 0 else { return nil }
            return CleanableItem(
                url: bundle.url, name: bundle.url.deletingPathExtension().lastPathComponent,
                detail: "\(bundle.app) virtual machine, including its disks.", category: .systemData,
                size: usage.size, fileCount: usage.fileCount, lastModified: usage.newestModification,
                isDirectory: true, safety: .review, action: .moveToTrash, selectedByDefault: false,
                ownerBundleID: bundle.owner, section: "Virtual Machines"
            )
        }

        if context.hasFullDiskAccess {
            let docker = context.url("Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw")
            let usage = FileSizer.measure(docker)
            if usage.size > 0 {
                items.append(CleanableItem(
                    url: docker, name: "Docker Desktop disk", detail: "Images, containers and volumes used by Docker.",
                    category: .systemData, size: usage.size, lastModified: usage.newestModification,
                    isDirectory: false, safety: .manual, action: .none, selectedByDefault: false,
                    ownerBundleID: "com.docker.docker", section: "Virtual Machines",
                    hint: "Run “docker system prune” to remove unused images, or lower the disk limit in Docker Desktop → Settings → Resources."
                ))
            }
        }
        return items
    }

    private static func developerData(_ context: ScanContext) async -> [CleanableItem] {
        let locations: [(name: String, url: URL, detail: String, hint: String)] = [
            ("Simulator devices", context.url("Library/Developer/CoreSimulator/Devices"),
             "Apps and data inside your iOS, watchOS and visionOS simulators.",
             "Use “Prune unavailable simulators” above, or delete simulators in Xcode → Window → Devices and Simulators."),
            ("Simulator runtimes", URL(fileURLWithPath: "/Library/Developer/CoreSimulator/Images"),
             "Installed simulator runtime images.",
             "Remove runtimes you no longer need in Xcode → Settings → Components."),
            ("Simulator runtimes (legacy)", URL(fileURLWithPath: "/Library/Developer/CoreSimulator/Profiles/Runtimes"),
             "Simulator runtimes installed by older Xcode versions.",
             "Remove runtimes you no longer need in Xcode → Settings → Components."),
        ]
        let present = locations.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        let measured = await present.concurrentMap { location in (location, FileSizer.measure(location.url)) }
        return measured.compactMap { pair in
            let (location, usage) = pair
            guard usage.size >= 50_000_000 else { return nil }
            return CleanableItem(
                url: location.url, name: location.name, detail: location.detail, category: .systemData,
                size: usage.size, fileCount: usage.fileCount, lastModified: usage.newestModification,
                isDirectory: true, safety: .manual, action: .none, selectedByDefault: false,
                ownerBundleID: "com.apple.dt.Xcode", section: "Developer", hint: location.hint
            )
        }
    }

    private static func macOSData(_ context: ScanContext) async -> [CleanableItem] {
        var items: [CleanableItem] = []

        let installers = children(of: URL(fileURLWithPath: "/Applications"), includeHidden: false)
            .filter { $0.lastPathComponent.hasPrefix("Install macOS") && $0.pathExtension == "app" }
        for installer in installers {
            let usage = FileSizer.measure(installer)
            guard usage.size > 0 else { continue }
            items.append(CleanableItem(
                url: installer, name: installer.deletingPathExtension().lastPathComponent,
                detail: "macOS installer. You can download it again from Apple.", category: .systemData,
                size: usage.size, fileCount: usage.fileCount, lastModified: usage.newestModification,
                isDirectory: true, safety: .review, action: .moveToTrash, selectedByDefault: false, section: "macOS"
            ))
        }

        let updates = URL(fileURLWithPath: "/Library/Updates")
        let updateUsage = FileSizer.measure(updates)
        if updateUsage.size >= 10_000_000 {
            items.append(CleanableItem(
                url: updates, name: "Downloaded macOS updates", detail: "Updates staged by Software Update.",
                category: .systemData, size: updateUsage.size, fileCount: updateUsage.fileCount,
                lastModified: updateUsage.newestModification, isDirectory: true, safety: .manual, action: .none,
                selectedByDefault: false, section: "macOS",
                hint: "Managed by macOS. Install or cancel the update in System Settings → General → Software Update."
            ))
        }

        guard context.hasFullDiskAccess else { return items }
        let groups: [(name: String, folder: String, detail: String, hint: String)] = [
            ("Telegram", "Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram",
             "Messages and media cached by Telegram.",
             "In Telegram, open Settings → Data and Storage → Storage Usage and choose Clear Cache."),
            ("Microsoft Office", "Library/Group Containers/UBF8T346G9.Office",
             "Shared data and caches for Word, Excel, PowerPoint and Outlook.",
             "Remove unused accounts in Outlook and clear caches from each app's settings."),
        ]
        for group in groups {
            let usage = FileSizer.measure(context.url(group.folder))
            guard usage.size >= 100_000_000 else { continue }
            items.append(CleanableItem(
                url: context.url(group.folder), name: group.name, detail: group.detail, category: .systemData,
                size: usage.size, fileCount: usage.fileCount, lastModified: usage.newestModification,
                isDirectory: true, safety: .manual, action: .none, selectedByDefault: false,
                section: "App Data", hint: group.hint
            ))
        }
        return items
    }

    // MARK: - Helpers

    static func children(of folder: URL, includeHidden: Bool) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: includeHidden ? [] : [.skipsHiddenFiles]
        )) ?? []
    }
}

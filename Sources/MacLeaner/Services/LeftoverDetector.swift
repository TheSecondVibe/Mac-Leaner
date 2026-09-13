import AppKit

/// Finds folders in ~/Library/Application Support that belong to apps that are gone.
///
/// Matching folders to apps is a heuristic, so it errs heavily on the side of
/// "still in use": a folder is only reported when no installed or running app
/// plausibly owns it, nothing inside was modified recently, and it isn't part of
/// macOS. Reported folders are never preselected and can only go to the Trash.
enum LeftoverDetector {
    struct InstalledApps: Sendable {
        var bundleIDs: Set<String> = []
        var names: Set<String> = []
    }

    static func scan(_ context: ScanContext) async -> [CleanableItem] {
        let installed = installedApps(home: context.home)
        let candidates = DiskScanner.children(of: context.url("Library/Application Support"), includeHidden: false)
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                    && !isSystemFolder(url.lastPathComponent)
                    && !isInstalled(folder: url.lastPathComponent, installed: installed)
            }
        let cutoff = context.now.addingTimeInterval(-Double(context.leftoverIdleDays) * 86_400)
        let measured = await candidates.concurrentMap { url in (url, FileSizer.measure(url)) }
        return measured.compactMap { pair in
            let (url, usage) = pair
            guard usage.size >= 1_000_000 else { return nil }
            // Something wrote here recently, so whatever owns it is still in use.
            if let newest = usage.newestModification, newest > cutoff { return nil }
            return CleanableItem(
                url: url, name: url.lastPathComponent, detail: "No installed app matches this folder",
                category: .leftovers, size: usage.size, fileCount: usage.fileCount,
                lastModified: usage.newestModification, isDirectory: true, safety: .review,
                action: .moveToTrash, selectedByDefault: false
            )
        }
    }

    static func installedApps(home: URL) -> InstalledApps {
        var apps = InstalledApps()
        let roots = [
            "/Applications", "/System/Applications", "/System/Library/CoreServices",
            home.appendingPathComponent("Applications").path,
        ]
        for root in roots {
            collectApps(in: URL(fileURLWithPath: root), depth: 3, into: &apps)
        }
        for app in NSWorkspace.shared.runningApplications {
            if let id = app.bundleIdentifier { apps.bundleIDs.insert(id.lowercased()) }
            if let name = app.localizedName { apps.names.insert(normalize(name)) }
        }
        return apps
    }

    private static func collectApps(in folder: URL, depth: Int, into apps: inout InstalledApps) {
        guard depth > 0 else { return }
        for url in DiskScanner.children(of: folder, includeHidden: false) {
            if url.pathExtension == "app" {
                apps.names.insert(normalize(url.deletingPathExtension().lastPathComponent))
                if let bundle = Bundle(url: url) {
                    if let id = bundle.bundleIdentifier { apps.bundleIDs.insert(id.lowercased()) }
                    for key in ["CFBundleName", "CFBundleExecutable", "CFBundleDisplayName"] {
                        if let value = bundle.object(forInfoDictionaryKey: key) as? String {
                            apps.names.insert(normalize(value))
                        }
                    }
                }
            } else if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                collectApps(in: url, depth: depth - 1, into: &apps)
            }
        }
    }

    static func isInstalled(folder: String, installed: InstalledApps) -> Bool {
        let lower = folder.lowercased()
        if AppDirectory.looksLikeBundleID(folder) {
            if installed.bundleIDs.contains(where: { $0 == lower || $0.hasPrefix(lower + ".") || lower.hasPrefix($0 + ".") }) {
                return true
            }
            if AppDirectory.appURL(for: folder) != nil { return true }
        }
        let key = normalize(folder)
        // Too short to judge reliably: leave it alone.
        guard key.count >= 3 else { return true }
        let nameMatch = installed.names.contains { name in
            !name.isEmpty && (name == key || name.hasPrefix(key) || key.hasPrefix(name) || (key.count >= 4 && name.contains(key)))
        }
        return nameMatch || installed.bundleIDs.contains { id in
            id.split(separator: ".").contains { normalize(String($0)) == key }
        }
    }

    /// Folders macOS and Apple apps keep in Application Support.
    static func isSystemFolder(_ folder: String) -> Bool {
        let name = folder.lowercased()
        if name.hasPrefix("com.apple") || name.contains("apple") { return true }
        return [
            "accessibility", "accounts", "addressbook", "animoji", "askpermission", "backgroundtaskmanagement",
            "bluetooth", "callhistorydb", "callhistorytransactions", "clouddocs", "cloudkit", "contacts",
            "controlcenter", "coreparsec", "coretelephony", "crashreporter", "dmd", "dock", "facetime",
            "familycircle", "fileprovider", "gamekit", "homeenergyd", "icdd", "icloud", "identityservices",
            "knowledge", "locationaccessstoremigrated", "managedclient", "maps", "mobilesync",
            "networkserviceproxy", "passkit", "photos", "quicklook", "sharedfilelist", "siri", "spotlight",
            "stocks", "syncservices", "tipsd", "trial", "universalaccess", "videoconference", "voicemail", "webkit",
        ].contains(name)
    }

    static func normalize(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter(CharacterSet.alphanumerics.contains).map(Character.init))
    }
}

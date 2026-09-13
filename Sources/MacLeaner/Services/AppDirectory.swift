import AppKit

/// Looks up installed apps by bundle identifier.
enum AppDirectory {
    static func looksLikeBundleID(_ name: String) -> Bool {
        name.split(separator: ".").count >= 3 && !name.contains(" ")
    }

    static func appURL(for bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    static func appName(for bundleID: String) -> String? {
        appURL(for: bundleID)?.deletingPathExtension().lastPathComponent
    }

    /// "com.google.Chrome" becomes "Google Chrome" when the app is installed, "Chrome" otherwise.
    static func displayName(forFolder folder: String) -> String {
        guard looksLikeBundleID(folder) else { return folder }
        if let name = appName(for: folder) { return name }
        let last = folder.split(separator: ".").last.map(String.init) ?? folder
        return last.prefix(1).uppercased() + last.dropFirst()
    }
}

extension Array where Element: Sendable {
    /// Maps elements concurrently, keeping their order. Used to measure many folders at once.
    func concurrentMap<T: Sendable>(_ transform: @escaping @Sendable (Element) -> T) async -> [T] {
        await withTaskGroup(of: (Int, T).self) { group in
            for (index, element) in enumerated() {
                group.addTask { (index, transform(element)) }
            }
            var results = [T?](repeating: nil, count: count)
            for await (index, value) in group {
                results[index] = value
            }
            return results.compactMap { $0 }
        }
    }
}

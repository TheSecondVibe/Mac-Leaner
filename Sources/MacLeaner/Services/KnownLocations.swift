import Foundation

/// Every fixed location Mac-Leaner knows about, in one reviewable place.
/// Paths are relative to the home folder. `SafetyPolicy` only allows permanent
/// deletion inside these entries (plus caches, logs and the Trash).
enum KnownLocations {
    struct Entry: Sendable {
        let name: String
        let path: String
        let detail: String
        var safety: Safety = .safe
        var action: CleanAction = .emptyContents
        var selected = true
        var owner: String? = nil
    }

    static let developer: [Entry] = [
        Entry(name: "Xcode DerivedData", path: "Library/Developer/Xcode/DerivedData",
              detail: "Build products and indexes. Xcode rebuilds them when needed.", owner: "com.apple.dt.Xcode"),
        Entry(name: "iOS Device Support", path: "Library/Developer/Xcode/iOS DeviceSupport",
              detail: "Debug symbols copied from iPhones and iPads. Copied again when you reconnect a device."),
        Entry(name: "watchOS Device Support", path: "Library/Developer/Xcode/watchOS DeviceSupport",
              detail: "Debug symbols copied from Apple Watch. Copied again when needed."),
        Entry(name: "tvOS Device Support", path: "Library/Developer/Xcode/tvOS DeviceSupport",
              detail: "Debug symbols copied from Apple TV. Copied again when needed."),
        Entry(name: "visionOS Device Support", path: "Library/Developer/Xcode/visionOS DeviceSupport",
              detail: "Debug symbols copied from Apple Vision Pro. Copied again when needed."),
        Entry(name: "SwiftUI Previews", path: "Library/Developer/Xcode/UserData/Previews",
              detail: "Simulators and caches used by Xcode previews.", owner: "com.apple.dt.Xcode"),
        Entry(name: "Simulator Caches", path: "Library/Developer/CoreSimulator/Caches",
              detail: "Runtime caches for simulators. Rebuilt automatically."),
        Entry(name: "Xcode Caches", path: "Library/Caches/com.apple.dt.Xcode",
              detail: "Xcode's download and index caches.", owner: "com.apple.dt.Xcode"),
        Entry(name: "Swift Package Manager", path: "Library/Caches/org.swift.swiftpm",
              detail: "Cached package repositories. Downloaded again when needed."),
        Entry(name: "CocoaPods", path: "Library/Caches/CocoaPods",
              detail: "Downloaded pod specs and sources."),
        Entry(name: "Xcode Archives", path: "Library/Developer/Xcode/Archives",
              detail: "Archived app builds and the dSYMs needed to read crash reports from released apps.",
              safety: .review, action: .moveToTrash, selected: false),
    ]

    static let packageCaches: [Entry] = [
        Entry(name: "Homebrew", path: "Library/Caches/Homebrew",
              detail: "Downloaded bottles and installers. Homebrew fetches them again if needed."),
        Entry(name: "npm", path: ".npm/_cacache", detail: "Package tarballs cached by npm."),
        Entry(name: "npx", path: ".npm/_npx", detail: "Packages cached by npx."),
        Entry(name: "Yarn", path: "Library/Caches/Yarn", detail: "Package cache for Yarn 1."),
        Entry(name: "Yarn Berry", path: ".yarn/berry/cache", detail: "Global cache for Yarn 2 and newer."),
        Entry(name: "pip", path: "Library/Caches/pip", detail: "Python wheels and downloads cached by pip."),
        Entry(name: "pip (XDG)", path: ".cache/pip", detail: "Python wheels and downloads cached by pip."),
        Entry(name: "uv", path: ".cache/uv", detail: "Python packages cached by uv."),
        Entry(name: "Poetry", path: "Library/Caches/pypoetry", detail: "Packages and virtualenv caches from Poetry."),
        Entry(name: "Cargo", path: ".cargo/registry/cache", detail: "Downloaded Rust crate archives."),
        Entry(name: "Go build cache", path: "Library/Caches/go-build", detail: "Compiled Go packages. Rebuilt on the next build."),
        Entry(name: "Gradle", path: ".gradle/caches", detail: "Dependencies and build caches. Offline builds will need them downloaded again."),
        Entry(name: "Bun", path: ".bun/install/cache", detail: "Packages cached by Bun."),
        Entry(name: "Deno", path: "Library/Caches/deno", detail: "Remote modules and compiled code cached by Deno."),
        Entry(name: "Composer", path: ".composer/cache", detail: "PHP packages cached by Composer."),
        Entry(name: "node-gyp", path: "Library/Caches/node-gyp", detail: "Node.js headers used to build native modules."),
        Entry(name: "pnpm store", path: "Library/pnpm/store",
              detail: "Projects link into this store; `pnpm store prune` is the gentler option.",
              safety: .review, selected: false),
        Entry(name: "Maven", path: ".m2/repository",
              detail: "Downloaded Java libraries. It can also hold artifacts you installed locally.",
              safety: .review, selected: false),
        Entry(name: "Playwright browsers", path: "Library/Caches/ms-playwright",
              detail: "Browsers downloaded for Playwright tests. Large to download again.",
              safety: .review, selected: false),
    ]

    /// Caches apps keep in Application Support. macOS counts these as System Data.
    static let appDataCaches: [Entry] = [
        Entry(name: "Claude VM bundles", path: "Library/Application Support/Claude/vm_bundles",
              detail: "Sandbox images downloaded by the Claude app. Downloaded again when needed.",
              owner: "com.anthropic.claudefordesktop"),
        Entry(name: "Claude cache", path: "Library/Application Support/Claude/Cache",
              detail: "Network and image cache of the Claude app.", owner: "com.anthropic.claudefordesktop"),
        Entry(name: "Claude code cache", path: "Library/Application Support/Claude/Code Cache",
              detail: "Compiled JavaScript cache of the Claude app.", owner: "com.anthropic.claudefordesktop"),
        Entry(name: "Chrome on-device AI model", path: "Library/Application Support/Google/Chrome/OptGuideOnDeviceModel",
              detail: "Chrome's local AI model. Downloaded again if the feature is used.", owner: "com.google.Chrome"),
        Entry(name: "Discord cache", path: "Library/Application Support/discord/Cache",
              detail: "Cached images, audio and video.", owner: "com.hnc.Discord"),
        Entry(name: "Discord code cache", path: "Library/Application Support/discord/Code Cache",
              detail: "Compiled JavaScript cache.", owner: "com.hnc.Discord"),
        Entry(name: "Discord GPU cache", path: "Library/Application Support/discord/GPUCache",
              detail: "Shader cache.", owner: "com.hnc.Discord"),
        Entry(name: "Slack cache", path: "Library/Application Support/Slack/Cache",
              detail: "Cached images and files.", owner: "com.tinyspeck.slackmacgap"),
        Entry(name: "Slack service worker cache", path: "Library/Application Support/Slack/Service Worker/CacheStorage",
              detail: "Offline web cache.", owner: "com.tinyspeck.slackmacgap"),
        Entry(name: "VS Code cache", path: "Library/Application Support/Code/Cache",
              detail: "Web view cache.", owner: "com.microsoft.VSCode"),
        Entry(name: "VS Code cached data", path: "Library/Application Support/Code/CachedData",
              detail: "Compiled code cache.", owner: "com.microsoft.VSCode"),
        Entry(name: "VS Code extension downloads", path: "Library/Application Support/Code/CachedExtensionVSIXs",
              detail: "Downloaded extension packages.", owner: "com.microsoft.VSCode"),
        Entry(name: "Cursor cache", path: "Library/Application Support/Cursor/Cache",
              detail: "Web view cache.", owner: "com.todesktop.230313mzl4w4u92"),
        Entry(name: "Cursor cached data", path: "Library/Application Support/Cursor/CachedData",
              detail: "Compiled code cache.", owner: "com.todesktop.230313mzl4w4u92"),
        Entry(name: "Antigravity cache", path: "Library/Application Support/Antigravity IDE/Cache",
              detail: "Cached runtime data."),
        Entry(name: "Spotify cache", path: "Library/Application Support/Spotify/PersistentCache",
              detail: "Streaming cache and downloaded songs. Downloads have to sync again.",
              safety: .review, owner: "com.spotify.client"),
    ]

    static let all: [Entry] = developer + packageCaches + appDataCaches

    static let permanentPaths: [String] = all.filter { $0.action.isPermanent }.map(\.path)

    /// Folders in ~/Library/Caches already shown by another category.
    static let claimedCacheFolders: Set<String> = Set(
        all.map(\.path).filter { $0.hasPrefix("Library/Caches/") }.map { String($0.dropFirst("Library/Caches/".count)) }
    )

    /// Caches macOS manages itself or that hold state (e.g. iCloud sync).
    static func isSystemCache(_ folder: String) -> Bool {
        folder.hasPrefix("com.apple.")
            || ["CloudKit", "FamilyCircle", "familycircled", "Metadata", "TemporaryItems", "PassKit", "storeassetd"].contains(folder)
    }
}

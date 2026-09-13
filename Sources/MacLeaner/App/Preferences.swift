import AppKit
import Observation
import ServiceManagement

/// User settings, persisted in UserDefaults.
@MainActor @Observable
final class Preferences {
    private enum Key {
        static let largeFileThresholdMB = "largeFileThresholdMB"
        static let leftoverIdleDays = "leftoverIdleDays"
        static let showSizeInMenuBar = "showSizeInMenuBar"
        static let showInDock = "showInDock"
        static let scanOnLaunch = "scanOnLaunch"
        static let excludedPaths = "excludedPaths"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    static let largeFileThresholds = [100, 250, 500, 1_000, 5_000]

    @ObservationIgnored private let defaults: UserDefaults

    var largeFileThresholdMB: Int {
        didSet { defaults.set(largeFileThresholdMB, forKey: Key.largeFileThresholdMB) }
    }
    var leftoverIdleDays: Int {
        didSet { defaults.set(leftoverIdleDays, forKey: Key.leftoverIdleDays) }
    }
    var showSizeInMenuBar: Bool {
        didSet { defaults.set(showSizeInMenuBar, forKey: Key.showSizeInMenuBar) }
    }
    var showInDock: Bool {
        didSet {
            defaults.set(showInDock, forKey: Key.showInDock)
            applyDockVisibility()
        }
    }
    var scanOnLaunch: Bool {
        didSet { defaults.set(scanOnLaunch, forKey: Key.scanOnLaunch) }
    }
    /// Paths that are never shown or cleaned.
    var excludedPaths: [String] {
        didSet { defaults.set(excludedPaths, forKey: Key.excludedPaths) }
    }
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.largeFileThresholdMB: 500,
            Key.leftoverIdleDays: 90,
            Key.showSizeInMenuBar: true,
            Key.showInDock: true,
            Key.scanOnLaunch: true,
        ])
        largeFileThresholdMB = defaults.integer(forKey: Key.largeFileThresholdMB)
        leftoverIdleDays = defaults.integer(forKey: Key.leftoverIdleDays)
        showSizeInMenuBar = defaults.bool(forKey: Key.showSizeInMenuBar)
        showInDock = defaults.bool(forKey: Key.showInDock)
        scanOnLaunch = defaults.bool(forKey: Key.scanOnLaunch)
        excludedPaths = defaults.stringArray(forKey: Key.excludedPaths) ?? []
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
    }

    var largeFileThreshold: Int64 { Int64(largeFileThresholdMB) * 1_000_000 }

    func applyDockVisibility() {
        NSApp?.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    // MARK: Launch at login (system state, so it isn't stored here)

    var launchesAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchesAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

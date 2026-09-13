import SwiftUI
import Observation

enum Route: Hashable {
    case overview
    case category(CleanCategory)
}

/// App state. All UI reads from here; disk work happens off the main actor in
/// `DiskScanner` and `CleanerEngine`.
@MainActor @Observable
final class AppModel {
    enum Tool: Equatable { case pruneSimulators, thinSnapshots }
    enum SelectionState { case none, partial, all }

    struct ToolResult: Identifiable, Sendable {
        let id = UUID()
        let title: String
        let message: String
        let succeeded: Bool
    }

    let preferences: Preferences
    let isDemo: Bool

    private(set) var metrics: SystemMetrics
    private(set) var itemsByCategory: [CleanCategory: [CleanableItem]] = [:]
    var selection: Set<String> = []
    private(set) var scanning: Set<CleanCategory> = []
    private(set) var lastScanDate: Date?
    private(set) var isCleaning = false
    private(set) var hasFullDiskAccess: Bool
    private(set) var snapshotCount: Int?
    private(set) var runningTool: Tool?

    var route: Route? = .overview
    var reviewRequest: ReviewRequest?
    var lastReport: CleanReport?
    var toolResult: ToolResult?
    var showOnboarding: Bool

    /// Set by the UI so the menu bar and Dock can bring the main window back.
    @ObservationIgnored var openMainWindow: (() -> Void)?
    /// Items seen before keep the user's selection across rescans.
    @ObservationIgnored private var knownIDs: Set<String> = []
    @ObservationIgnored private var pendingRescan: Set<CleanCategory> = []
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var metricsTask: Task<Void, Never>?

    private var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    init(preferences: Preferences, isDemo: Bool) {
        self.preferences = preferences
        self.isDemo = isDemo
        metrics = isDemo ? DemoData.metrics : .current()
        hasFullDiskAccess = isDemo || Permissions.hasFullDiskAccess
        showOnboarding = !isDemo && !preferences.hasCompletedOnboarding
        startMetricsUpdates()
    }

    /// Runs once, when the main window first appears.
    func appDidLaunch() {
        guard !didLaunch else { return }
        didLaunch = true
        if isDemo || (preferences.hasCompletedOnboarding && preferences.scanOnLaunch) {
            startScan()
        }
    }

    // MARK: - Queries

    var isScanning: Bool { !scanning.isEmpty }
    var hasScanned: Bool { lastScanDate != nil }

    func items(in category: CleanCategory) -> [CleanableItem] { itemsByCategory[category] ?? [] }
    func isScanned(_ category: CleanCategory) -> Bool { itemsByCategory[category] != nil }
    func isScanning(_ category: CleanCategory) -> Bool { scanning.contains(category) }

    func cleanableSize(of category: CleanCategory) -> Int64 {
        items(in: category).reduce(0) { $1.isCleanable ? $0 + $1.size : $0 }
    }

    func selectedItems(in category: CleanCategory) -> [CleanableItem] {
        items(in: category).filter { $0.isCleanable && selection.contains($0.id) }
    }

    func selectedSize(of category: CleanCategory) -> Int64 {
        selectedItems(in: category).reduce(0) { $0 + $1.size }
    }

    var allSelectedItems: [CleanableItem] { CleanCategory.allCases.flatMap(selectedItems(in:)) }
    var selectedTotal: Int64 { allSelectedItems.reduce(0) { $0 + $1.size } }
    var cleanupTotal: Int64 { CleanCategory.cleanup.reduce(0) { $0 + cleanableSize(of: $1) } }
    var reviewTotal: Int64 { CleanCategory.review.reduce(0) { $0 + cleanableSize(of: $1) } }

    // MARK: - Selection

    func isSelected(_ item: CleanableItem) -> Bool { selection.contains(item.id) }

    func setSelected(_ item: CleanableItem, _ selected: Bool) {
        guard item.isCleanable else { return }
        if selected { selection.insert(item.id) } else { selection.remove(item.id) }
    }

    func setSelected(_ items: [CleanableItem], _ selected: Bool) {
        let ids = items.filter(\.isCleanable).map(\.id)
        if selected { selection.formUnion(ids) } else { selection.subtract(ids) }
    }

    func selectionState(of category: CleanCategory) -> SelectionState {
        let cleanable = items(in: category).filter(\.isCleanable)
        let selected = cleanable.filter { selection.contains($0.id) }.count
        if selected == 0 { return .none }
        return selected == cleanable.count ? .all : .partial
    }

    func toggleSelection(of category: CleanCategory) {
        setSelected(items(in: category), selectionState(of: category) != .all)
    }

    // MARK: - Scanning

    func startScan() { scan(CleanCategory.allCases) }

    /// Scans categories in parallel; each category's results appear as soon as it finishes.
    func scan(_ categories: [CleanCategory]) {
        guard !isCleaning, !categories.isEmpty else { return }
        guard !isScanning else {
            pendingRescan.formUnion(categories)
            return
        }
        scanning = Set(categories)
        hasFullDiskAccess = isDemo || Permissions.hasFullDiskAccess
        let context = ScanContext(
            home: home,
            largeFileThreshold: preferences.largeFileThreshold,
            leftoverIdleDays: preferences.leftoverIdleDays,
            hasFullDiskAccess: hasFullDiskAccess,
            ownBundleID: Bundle.main.bundleIdentifier
        )
        let demo = isDemo

        scanTask = Task {
            await withTaskGroup(of: (CleanCategory, [CleanableItem]).self) { group in
                for category in categories {
                    group.addTask {
                        if demo { return (category, await Self.demoScan(category, threshold: context.largeFileThreshold)) }
                        return (category, await DiskScanner.scan(category, in: context))
                    }
                }
                for await (category, items) in group where !Task.isCancelled {
                    apply(items, to: category)
                    scanning.remove(category)
                }
            }
            scanning.removeAll()
            lastScanDate = .now
            refreshMetrics()
            if categories.contains(.systemData) {
                snapshotCount = demo ? 2 : await SystemTools.localSnapshotCount()
            }
            if !pendingRescan.isEmpty {
                let next = Array(pendingRescan)
                pendingRescan.removeAll()
                scan(next)
            }
        }
    }

    func cancelScan() {
        pendingRescan.removeAll()
        scanTask?.cancel()
    }

    private func apply(_ items: [CleanableItem], to category: CleanCategory) {
        let excluded = preferences.excludedPaths
        let visible = items.filter { item in
            !excluded.contains { item.id == $0 || item.id.hasPrefix($0 + "/") }
        }
        for item in visible where !knownIDs.contains(item.id) {
            knownIDs.insert(item.id)
            if item.selectedByDefault && item.isCleanable { selection.insert(item.id) }
        }
        itemsByCategory[category] = visible
    }

    nonisolated private static func demoScan(_ category: CleanCategory, threshold: Int64) async -> [CleanableItem] {
        let order = CleanCategory.allCases.firstIndex(of: category) ?? 0
        try? await Task.sleep(for: .milliseconds(350 + 160 * order))
        return DemoData.items(for: category).filter { category != .largeFiles || $0.size >= threshold }
    }

    // MARK: - Cleaning

    /// Opens the review sheet for the selected items (optionally limited to some categories).
    func reviewSelection(in categories: [CleanCategory] = CleanCategory.allCases) {
        let items = categories.flatMap(selectedItems(in:))
        guard !items.isEmpty, !isCleaning else { return }
        reviewRequest = ReviewRequest(items: items)
    }

    func clean(_ request: ReviewRequest) {
        reviewRequest = nil
        guard !isCleaning, !isScanning else { return }
        isCleaning = true
        let items = request.items
        let policy = SafetyPolicy(home: home, excludedPaths: preferences.excludedPaths)
        let available = metrics.availableDisk

        Task {
            let report = isDemo
                ? DemoData.report(for: items, available: available)
                : await CleanerEngine(policy: policy).clean(items)
            finishClean(report, items: items)
        }
    }

    private func finishClean(_ report: CleanReport, items: [CleanableItem]) {
        let cleaned = Set(report.cleanedIDs)
        for category in itemsByCategory.keys {
            itemsByCategory[category]?.removeAll { cleaned.contains($0.id) }
        }
        selection.subtract(cleaned)
        knownIDs.subtract(cleaned)
        // Just moved to the Trash: never preselect those for permanent deletion.
        knownIDs.formUnion(report.trashedPaths)
        if isDemo { metrics.availableDisk = report.availableAfter }
        isCleaning = false
        lastReport = report
        refreshMetrics()

        guard !isDemo else { return }
        var affected = Set(items.map(\.category))
        if report.trashedBytes > 0 { affected.insert(.trash) }
        scan(Array(affected))
    }

    // MARK: - Tools

    func pruneSimulators() {
        let home = self.home
        runTool(
            .pruneSimulators,
            demoResult: ToolResult(title: "Simulators pruned", message: "Removed 4 simulators whose runtimes are no longer installed.", succeeded: true)
        ) {
            guard await SystemTools.simulatorToolsAvailable() else {
                return ToolResult(title: "Xcode not found", message: "Pruning simulators needs Xcode to be installed.", succeeded: false)
            }
            let before = SystemMetrics.availableDiskSpace(at: home)
            let output = await SystemTools.pruneUnavailableSimulators()
            let freed = SystemMetrics.availableDiskSpace(at: home) - before
            guard output.succeeded else {
                return ToolResult(title: "Couldn't prune simulators", message: output.text.isEmpty ? "simctl exited with status \(output.status)." : output.text, succeeded: false)
            }
            let message = freed > 50_000_000
                ? "Removed simulators whose runtimes are no longer installed and freed about \(freed.byteString)."
                : "Done. There were no unavailable simulators taking up significant space."
            return ToolResult(title: "Unavailable simulators removed", message: message, succeeded: true)
        }
    }

    func thinSnapshots() {
        let home = self.home
        runTool(
            .thinSnapshots,
            demoResult: ToolResult(title: "Snapshots thinned", message: "macOS released about 3.2 GB held by local Time Machine snapshots.", succeeded: true)
        ) {
            let before = SystemMetrics.availableDiskSpace(at: home)
            let output = await SystemTools.thinLocalSnapshots()
            let released = SystemMetrics.availableDiskSpace(at: home) - before
            guard output.succeeded else {
                return ToolResult(title: "Couldn't thin snapshots", message: output.text.isEmpty ? "tmutil exited with status \(output.status)." : output.text, succeeded: false)
            }
            let message = released > 50_000_000
                ? "macOS released about \(released.byteString) held by local snapshots."
                : "macOS didn't need to release any space. Local snapshots are removed automatically when space runs low."
            return ToolResult(title: "Snapshots thinned", message: message, succeeded: true)
        }
    }

    private func runTool(_ tool: Tool, demoResult: ToolResult, work: @escaping @Sendable () async -> ToolResult) {
        guard runningTool == nil, !isCleaning else { return }
        runningTool = tool
        Task {
            let result = isDemo ? demoResult : await work()
            runningTool = nil
            toolResult = result
            refreshMetrics()
            guard !isDemo else { return }
            snapshotCount = await SystemTools.localSnapshotCount()
            scan([.systemData])
        }
    }

    // MARK: - Exclusions, permissions, onboarding

    @ObservationIgnored private var didLaunch = false

    func exclude(_ item: CleanableItem) { excludePath(item.id) }

    /// Hides a location, and everything inside it, now and in future scans.
    func excludePath(_ path: String) {
        if !preferences.excludedPaths.contains(path) { preferences.excludedPaths.append(path) }
        for category in itemsByCategory.keys {
            itemsByCategory[category]?.removeAll { $0.id == path || $0.id.hasPrefix(path + "/") }
        }
        selection = selection.filter { $0 != path && !$0.hasPrefix(path + "/") }
    }

    func removeExclusion(_ path: String) {
        preferences.excludedPaths.removeAll { $0 == path }
    }

    func refreshPermissions() {
        let hadAccess = hasFullDiskAccess
        hasFullDiskAccess = isDemo || Permissions.hasFullDiskAccess
        if !hadAccess, hasFullDiskAccess, hasScanned {
            scan([.trash, .systemData])
        }
    }

    func completeOnboarding(startScanning: Bool) {
        preferences.hasCompletedOnboarding = true
        showOnboarding = false
        if startScanning { startScan() }
    }

    // MARK: - Metrics

    func refreshMetrics() {
        guard !isDemo else { return }
        metrics = .current()
    }

    private func startMetricsUpdates() {
        guard !isDemo else { return }
        metricsTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                self?.refreshMetrics()
            }
        }
    }
}

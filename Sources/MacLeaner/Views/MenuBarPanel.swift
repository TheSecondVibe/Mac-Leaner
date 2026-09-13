import AppKit
import SwiftUI

struct MenuBarLabel: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: model.isScanning ? "sparkle.magnifyingglass" : "sparkles")
            if model.preferences.showSizeInMenuBar, model.selectedTotal > 0 {
                Text(model.selectedTotal.byteString).monospacedDigit()
            }
        }
        .accessibilityLabel("Mac-Leaner")
        // The menu bar item exists from launch even when macOS doesn't restore the
        // main window (for example at login), so launch work starts here.
        .task {
            model.preferences.applyDockVisibility()
            model.appDidLaunch()
            if SnapshotExporter.outputFolder != nil {
                openWindow(id: "main")
                Task { await SnapshotExporter.run(model: model) }
            }
        }
    }
}

/// The popover shown from the menu bar.
struct MenuBarPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let metrics = model.metrics
        let found = model.cleanupTotal + model.reviewTotal

        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.s) {
                BrandMark(size: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Mac-Leaner").font(.headline)
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showMainWindow() } label: {
                    Image(systemName: "macwindow")
                }
                .buttonStyle(.borderless)
                .help("Open Mac-Leaner")
                .accessibilityLabel("Open Mac-Leaner")

                Menu {
                    Button("Settings…") {
                        openSettings()
                        NSApp.activate()
                    }
                    Divider()
                    Button("Quit Mac-Leaner") { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("More")
            }
            .padding(Theme.Spacing.m)

            Divider()

            HStack(spacing: Theme.Spacing.m) {
                StorageRing(
                    usage: metrics.diskUsage,
                    cleanable: Double(found) / Double(max(metrics.totalDisk, 1)),
                    lineWidth: 7,
                    trackColor: .primary.opacity(0.1),
                    isScanning: model.isScanning
                )
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(metrics.availableDisk.byteString) available")
                        .font(.headline)
                        .monospacedDigit()
                    Text("of \(metrics.totalDisk.byteString) · memory \(Int(metrics.memoryUsage * 100))% used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
            }
            .padding(Theme.Spacing.m)

            VStack(spacing: 1) {
                ForEach(CleanCategory.allCases) { category in
                    MenuCategoryRow(category: category) { showMainWindow(route: .category(category)) }
                }
            }
            .padding(.horizontal, Theme.Spacing.s)

            Divider().padding(.top, Theme.Spacing.s)

            HStack(spacing: Theme.Spacing.s) {
                if model.isScanning {
                    Button("Stop") { model.cancelScan() }
                } else {
                    Button { model.startScan() } label: {
                        Label("Scan", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.isCleaning)
                }
                Spacer()
                Button {
                    showMainWindow()
                    model.reviewSelection()
                } label: {
                    Text(model.selectedTotal > 0 ? "Clean \(model.selectedTotal.byteString)…" : "Clean…")
                        .monospacedDigit()
                }
                .buttonStyle(.primary)
                .disabled(model.selectedTotal == 0 || model.isScanning || model.isCleaning)
            }
            .padding(Theme.Spacing.m)
        }
        .frame(width: 340)
    }

    private var status: String {
        if model.isScanning { return "Scanning…" }
        if model.isCleaning { return "Cleaning…" }
        if let date = model.lastScanDate { return "Scanned \(date.formatted(.relative(presentation: .named)))" }
        return "Not scanned yet"
    }

    private func showMainWindow(route: Route? = nil) {
        if let route { model.route = route }
        openWindow(id: "main")
        NSApp.activate()
    }
}

private struct MenuCategoryRow: View {
    let category: CleanCategory
    let open: () -> Void

    @Environment(AppModel.self) private var model
    @State private var isHovering = false

    var body: some View {
        Button(action: open) {
            HStack(spacing: Theme.Spacing.s) {
                IconTile(symbol: category.symbol, tint: category.tint, size: 22)
                Text(category.title)
                Spacer()
                if model.isScanning(category) {
                    ProgressView().controlSize(.mini)
                } else if model.isScanned(category) {
                    Text(model.cleanableSize(of: category).byteString)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(isHovering ? Color.primary.opacity(0.08) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

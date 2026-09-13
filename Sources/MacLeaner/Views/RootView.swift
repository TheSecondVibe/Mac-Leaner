import AppKit
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 210, ideal: 232, max: 300)
        } detail: {
            detail
                .frame(minWidth: 640, minHeight: 540)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if model.isScanning {
                    Button { model.cancelScan() } label: {
                        Label("Stop Scan", systemImage: "stop.circle")
                    }
                    .help("Stop scanning")
                } else {
                    Button { model.startScan() } label: {
                        Label("Scan", systemImage: "arrow.clockwise")
                    }
                    .help("Scan again")
                    .disabled(model.isCleaning)
                }
            }
        }
        .sheet(item: $model.reviewRequest) { ReviewSheet(request: $0) }
        .sheet(item: $model.lastReport) { ResultSheet(report: $0) }
        .sheet(isPresented: $model.showOnboarding) { OnboardingView() }
        .alert(
            model.toolResult?.title ?? "",
            isPresented: Binding(get: { model.toolResult != nil }, set: { if !$0 { model.toolResult = nil } }),
            presenting: model.toolResult
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { result in
            Text(result.message)
        }
        .onChange(of: model.preferences.largeFileThresholdMB) {
            if model.hasScanned { model.scan([.largeFiles]) }
        }
        .onChange(of: model.preferences.leftoverIdleDays) {
            if model.hasScanned { model.scan([.leftovers]) }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshPermissions()
        }
        .onAppear {
            model.openMainWindow = { openWindow(id: "main") }
        }
    }

    @ViewBuilder private var detail: some View {
        switch model.route ?? .overview {
        case .overview:
            OverviewView()
        case .category(.largeFiles):
            LargeFilesView()
        case let .category(category):
            CategoryView(category: category).id(category)
        }
    }
}

private struct Sidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        List(selection: $model.route) {
            Label("Overview", systemImage: "gauge.with.dots.needle.67percent")
                .tag(Route.overview)
            Section("Cleanup") {
                ForEach(CleanCategory.cleanup) { SidebarRow(category: $0).tag(Route.category($0)) }
            }
            Section("Review") {
                ForEach(CleanCategory.review) { SidebarRow(category: $0).tag(Route.category($0)) }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            DiskSummary().padding(Theme.Spacing.m)
        }
    }
}

private struct SidebarRow: View {
    let category: CleanCategory
    @Environment(AppModel.self) private var model

    var body: some View {
        Label {
            HStack(spacing: Theme.Spacing.xs) {
                Text(category.title)
                Spacer(minLength: Theme.Spacing.xs)
                if model.isScanning(category) {
                    ProgressView().controlSize(.mini)
                } else if model.isScanned(category) {
                    Text(model.cleanableSize(of: category).byteString)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: category.symbol)
                .foregroundStyle(category.tint)
        }
    }
}

private struct DiskSummary: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let metrics = model.metrics
        VStack(alignment: .leading, spacing: 6) {
            Label(model.isDemo ? "Macintosh HD" : FileManager.default.displayName(atPath: "/"), systemImage: "internaldrive")
                .font(.caption.weight(.semibold))
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1))
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.indigo, Theme.azure], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * min(1, metrics.diskUsage))
                }
            }
            .frame(height: 6)
            Text("\(metrics.availableDisk.byteString) available of \(metrics.totalDisk.byteString)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
        .accessibilityElement(children: .combine)
    }
}

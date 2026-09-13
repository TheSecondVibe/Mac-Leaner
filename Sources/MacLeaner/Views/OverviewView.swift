import SwiftUI

struct OverviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                HeroPanel()
                if !model.hasFullDiskAccess {
                    FullDiskAccessBanner()
                }
                CategoryGrid(
                    title: "Cleanup",
                    subtitle: "Caches, logs and build products. Apps recreate these when they need them.",
                    categories: CleanCategory.cleanup
                )
                CategoryGrid(
                    title: "Needs your review",
                    subtitle: "Your files and app data. Nothing here is selected until you choose it.",
                    categories: CleanCategory.review
                )
                StatusFooter()
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: Theme.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Overview")
    }
}

// MARK: - Hero

private struct HeroPanel: View {
    @Environment(AppModel.self) private var model

    private var foundTotal: Int64 { model.cleanupTotal + model.reviewTotal }

    var body: some View {
        let metrics = model.metrics
        let total = Double(max(metrics.totalDisk, 1))

        HStack(spacing: Theme.Spacing.xxl) {
            ZStack {
                StorageRing(
                    usage: metrics.diskUsage,
                    cleanable: Double(foundTotal) / total,
                    lineWidth: 16,
                    isScanning: model.isScanning
                )
                VStack(spacing: 0) {
                    Text(metrics.availableDisk.byteString)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("available")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .foregroundStyle(.white)
            }
            .frame(width: 176, height: 176)

            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text(volumeName.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.6))

                headline

                Text(message)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                actions
                    .padding(.top, Theme.Spacing.xs)

                Legend(metrics: metrics, cleanable: foundTotal)
                    .padding(.top, Theme.Spacing.xs)
            }
            Spacer(minLength: 0)
        }
        .padding(28)
        .background(HeroBackground())
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
        .environment(\.colorScheme, .dark)
        .animation(.easeOut(duration: 0.25), value: model.isScanning)
    }

    private var volumeName: String {
        model.isDemo ? "Macintosh HD" : FileManager.default.displayName(atPath: "/")
    }

    @ViewBuilder private var headline: some View {
        if model.isScanning {
            BigNumber(bytes: foundTotal, caption: "found so far")
        } else if !model.hasScanned {
            Text("See what's taking up space")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        } else if model.selectedTotal > 0 {
            BigNumber(bytes: model.selectedTotal, caption: "ready to clean")
        } else {
            Text("Your Mac is looking lean")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var message: String {
        if model.isScanning {
            let remaining = model.scanning.count
            return "Checking \(remaining) \(remaining == 1 ? "category" : "categories")… Results appear as each one finishes."
        }
        if !model.hasScanned {
            return "Mac-Leaner looks through caches, logs, developer files, large files and more. Nothing is removed until you review it."
        }
        return "\(model.cleanupTotal.byteString) in caches and logs, plus \(model.reviewTotal.byteString) of files and app data to review."
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: Theme.Spacing.s) {
            if model.isScanning {
                Button("Stop Scan") { model.cancelScan() }
                    .buttonStyle(.glass)
            } else if !model.hasScanned {
                Button { model.startScan() } label: {
                    Label("Scan Now", systemImage: "sparkle.magnifyingglass")
                }
                .buttonStyle(.primary)
            } else {
                Button { model.reviewSelection() } label: {
                    Label("Review & Clean…", systemImage: "sparkles")
                }
                .buttonStyle(.primary)
                .disabled(model.selectedTotal == 0 || model.isCleaning)

                Button { model.startScan() } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .disabled(model.isCleaning)
            }
        }
    }
}

private struct BigNumber: View {
    let bytes: Int64
    let caption: String

    var body: some View {
        let parts = bytes.byteParts
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(parts.value)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(parts.unit)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
            Text(caption)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.leading, 4)
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}

private struct Legend: View {
    let metrics: SystemMetrics
    let cleanable: Int64

    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            item(color: Theme.azure, title: "Used", value: max(0, metrics.usedDisk - cleanable))
            item(color: Theme.mint, title: "Can be cleaned", value: cleanable)
            item(color: .white.opacity(0.25), title: "Free", value: metrics.availableDisk)
        }
        .font(.caption)
    }

    private func item(color: Color, title: String, value: Int64) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).foregroundStyle(.white.opacity(0.65))
            Text(value.byteString).foregroundStyle(.white).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Navy panel with soft brand-colored light, like the app icon.
private struct HeroBackground: View {
    var body: some View {
        ZStack {
            Theme.heroGradient
            RadialGradient(colors: [Theme.indigo.opacity(0.55), .clear], center: .topLeading, startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Theme.mint.opacity(0.22), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 360)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        )
    }
}

// MARK: - Category grid

private struct CategoryGrid: View {
    let title: String
    let subtitle: String
    let categories: [CleanCategory]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.weight(.semibold))
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: Theme.Spacing.m)], spacing: Theme.Spacing.m) {
                ForEach(categories) { CategoryCard(category: $0) }
            }
        }
    }
}

private struct CategoryCard: View {
    let category: CleanCategory
    @Environment(AppModel.self) private var model
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                model.route = .category(category)
            } label: {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    IconTile(symbol: category.symbol, tint: category.tint, size: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        status
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(category.tint.opacity(isHovering ? 0.55 : 0), lineWidth: 1.5)
                )
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(category.title), \(accessibilitySummary)")
            .accessibilityHint("Shows the items in this category")

            if !category.isReview && !model.items(in: category).filter(\.isCleanable).isEmpty {
                // Checked while anything in the category is selected, so a partly
                // selected category never looks empty; clicking selects or clears all.
                Toggle("Include \(category.title)", isOn: Binding(
                    get: { model.selectionState(of: category) != .none },
                    set: { model.setSelected(model.items(in: category), $0) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .padding(Theme.Spacing.l)
                .help("Include everything in \(category.title)")
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(Theme.Spacing.l + 2)
                    .accessibilityHidden(true)
            }
        }
        .scaleEffect(isHovering ? 1.01 : 1)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }

    @ViewBuilder private var status: some View {
        if model.isScanning(category) && !model.isScanned(category) {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Scanning…").foregroundStyle(.secondary)
            }
            .font(.callout)
            .frame(height: 38, alignment: .leading)
        } else if !model.isScanned(category) {
            Text("Not scanned yet")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(height: 38, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text(model.cleanableSize(of: category).byteString)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detail: String {
        let items = model.items(in: category)
        if items.isEmpty { return "Nothing found" }
        if category.isReview {
            return "\(items.count) \(items.count == 1 ? "item" : "items") to review"
        }
        return "\(items.count) \(items.count == 1 ? "item" : "items") · \(model.selectedSize(of: category).byteString) selected"
    }

    private var accessibilitySummary: String {
        model.isScanned(category) ? "\(model.cleanableSize(of: category).byteString), \(detail)" : "not scanned yet"
    }
}

private struct StatusFooter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            Label {
                Text("Memory \(Int64(model.metrics.usedMemory).byteString) of \(Int64(model.metrics.totalMemory).byteString) in use")
            } icon: {
                Image(systemName: "memorychip")
            }
            if let date = model.lastScanDate {
                Label {
                    Text("Last scan \(date, format: .relative(presentation: .named))")
                } icon: {
                    Image(systemName: "clock")
                }
            }
            Spacer()
            Label("Nothing leaves your Mac", systemImage: "lock.fill")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
}

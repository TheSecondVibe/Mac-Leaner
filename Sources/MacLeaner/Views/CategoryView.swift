import SwiftUI

/// The list for one category: header, optional tools, items, and the clean bar.
struct CategoryView: View {
    let category: CleanCategory

    @Environment(AppModel.self) private var model
    @State private var searchText = ""
    @State private var sort: Sort = .size

    enum Sort: String, CaseIterable, Identifiable {
        case size = "Size"
        case name = "Name"
        case date = "Last Modified"
        var id: String { rawValue }
    }

    private var visibleItems: [CleanableItem] {
        var items = model.items(in: category)
        if !searchText.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) || $0.detail.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sort {
        case .size: items.sort { $0.size > $1.size }
        case .name: items.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .date: items.sort { $0.sortDate < $1.sortDate }
        }
        return items
    }

    private var needsFullDiskAccess: Bool {
        !model.hasFullDiskAccess && (category == .trash || category == .systemData)
    }

    var body: some View {
        let items = visibleItems
        let maxSize = items.map(\.size).max() ?? 0

        VStack(spacing: 0) {
            CategoryHeader(category: category)

            if category == .systemData || needsFullDiskAccess {
                VStack(spacing: Theme.Spacing.m) {
                    if needsFullDiskAccess { FullDiskAccessBanner() }
                    if category == .systemData { SystemDataTools() }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.m)
            }

            Divider()

            List {
                if category == .systemData {
                    ForEach(sections(of: items), id: \.title) { section in
                        Section(section.title) {
                            ForEach(section.items) { ItemRow(item: $0, maxSize: maxSize) }
                        }
                    }
                } else {
                    ForEach(items) { ItemRow(item: $0, maxSize: maxSize) }
                }
            }
            .listStyle(.inset)
            .overlay { emptyState(itemsAreEmpty: items.isEmpty) }

            CleanBar(categories: [category])
        }
        .navigationTitle(category.title)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search \(category.title)")
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Picker("Sort By", selection: $sort) {
                        ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .help("Sort items")

                Menu {
                    Button("Select All") { model.setSelected(items, true) }
                    Button("Select None") { model.setSelected(items, false) }
                } label: {
                    Label("Selection", systemImage: "checklist")
                }
                .help("Select or deselect the items shown")
                .disabled(items.allSatisfy { !$0.isCleanable })
            }
        }
    }

    @ViewBuilder
    private func emptyState(itemsAreEmpty: Bool) -> some View {
        if itemsAreEmpty {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if !model.isScanned(category) && model.isScanning(category) {
                ProgressView("Scanning \(category.title)…")
            } else if !model.isScanned(category) {
                ContentUnavailableView {
                    Label("Not scanned yet", systemImage: category.symbol)
                } description: {
                    Text(category.summary)
                } actions: {
                    Button("Scan Now") { model.startScan() }
                        .buttonStyle(.primary)
                }
            } else if category == .trash && !model.hasFullDiskAccess {
                ContentUnavailableView(
                    "Trash isn't visible",
                    systemImage: "lock.shield",
                    description: Text("Allow Full Disk Access so Mac-Leaner can see what's in your Trash.")
                )
            } else {
                ContentUnavailableView(
                    "Nothing to clean",
                    systemImage: "checkmark.seal",
                    description: Text("Mac-Leaner didn't find anything worth removing here.")
                )
            }
        }
    }

    private func sections(of items: [CleanableItem]) -> [(title: String, items: [CleanableItem])] {
        let order = ["Virtual Machines", "App Data", "Developer", "macOS"]
        let grouped = Dictionary(grouping: items) { $0.section ?? "Other" }
        return grouped.keys
            .sorted { (order.firstIndex(of: $0) ?? order.count, $0) < (order.firstIndex(of: $1) ?? order.count, $1) }
            .map { (title: $0, items: grouped[$0] ?? []) }
    }
}

// MARK: - Header

struct CategoryHeader<Accessory: View>: View {
    let category: CleanCategory
    @ViewBuilder var accessory: Accessory

    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.m) {
            IconTile(symbol: category.symbol, tint: category.tint, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(.title2.weight(.bold))
                Text(category.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.Spacing.l)
            accessory
            VStack(alignment: .trailing, spacing: 1) {
                Text(model.cleanableSize(of: category).byteString)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(category.isReview ? "to review" : "can be cleaned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.l)
    }
}

extension CategoryHeader where Accessory == EmptyView {
    init(category: CleanCategory) {
        self.init(category: category) { EmptyView() }
    }
}

// MARK: - Clean bar

/// Footer with the selection summary and the one primary action.
struct CleanBar: View {
    let categories: [CleanCategory]
    @Environment(AppModel.self) private var model

    var body: some View {
        let selected = categories.flatMap(model.selectedItems(in:))
        let size = selected.reduce(0) { $0 + $1.size }
        // Name the action after what the selection (or, if nothing is selected,
        // the category) would actually do.
        let candidates = selected.isEmpty ? categories.flatMap(model.items(in:)).filter(\.isCleanable) : selected
        let trashOnly = !candidates.isEmpty && candidates.allSatisfy { $0.action == .moveToTrash }
        let title = switch (selected.isEmpty, trashOnly) {
        case (true, true): "Move to Trash…"
        case (true, false): "Clean…"
        case (false, true): "Move \(size.byteString) to Trash…"
        case (false, false): "Clean \(size.byteString)…"
        }

        HStack(spacing: Theme.Spacing.m) {
            if model.isCleaning {
                ProgressView().controlSize(.small)
                Text("Cleaning…").foregroundStyle(.secondary)
            } else {
                Text(selected.isEmpty ? "Nothing selected" : "\(selected.count) selected · \(size.byteString)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Button {
                model.reviewSelection(in: categories)
            } label: {
                Label(title, systemImage: trashOnly ? "trash" : "sparkles")
                    .monospacedDigit()
            }
            .buttonStyle(.primary)
            .disabled(selected.isEmpty || model.isCleaning || model.isScanning)
            .keyboardShortcut(.delete, modifiers: .command)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

// MARK: - System Data tools

struct SystemDataTools: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ToolCard(
                title: "Prune unavailable simulators",
                subtitle: "Deletes simulators whose runtime is no longer installed.",
                symbol: "iphone.slash",
                isRunning: model.runningTool == .pruneSimulators,
                action: model.pruneSimulators
            )
            ToolCard(
                title: "Thin local snapshots",
                subtitle: snapshotSubtitle,
                symbol: "clock.arrow.circlepath",
                isRunning: model.runningTool == .thinSnapshots,
                action: model.thinSnapshots
            )
        }
        .disabled(model.runningTool != nil || model.isCleaning)
    }

    private var snapshotSubtitle: String {
        switch model.snapshotCount {
        case .none: "Asks macOS to release space held by Time Machine."
        case 0: "No local Time Machine snapshots right now."
        case let count?: "\(count) local \(count == 1 ? "snapshot" : "snapshots"). Asks macOS to release their space."
        }
    }
}

private struct ToolCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            IconTile(symbol: symbol, tint: Theme.accent, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.Spacing.s)
            if isRunning {
                ProgressView().controlSize(.small)
            } else {
                Button("Run", action: action)
                    .accessibilityLabel(title)
            }
        }
        .card(padding: Theme.Spacing.m)
        .frame(maxWidth: .infinity)
    }
}

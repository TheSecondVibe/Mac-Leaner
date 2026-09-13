import SwiftUI

/// Large files as a sortable, Finder-style table.
struct LargeFilesView: View {
    @Environment(AppModel.self) private var model
    @State private var sortOrder = [KeyPathComparator(\CleanableItem.size, order: .reverse)]
    @State private var searchText = ""
    @State private var highlighted = Set<CleanableItem.ID>()

    private var rows: [CleanableItem] {
        let items = model.items(in: .largeFiles).filter {
            searchText.isEmpty
                || $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.detail.localizedCaseInsensitiveContains(searchText)
        }
        return items.sorted(using: sortOrder)
    }

    var body: some View {
        @Bindable var preferences = model.preferences
        let rows = rows

        VStack(spacing: 0) {
            CategoryHeader(category: .largeFiles) {
                Picker("Larger than", selection: $preferences.largeFileThresholdMB) {
                    ForEach(Preferences.largeFileThresholds, id: \.self) { megabytes in
                        Text((Int64(megabytes) * 1_000_000).byteString).tag(megabytes)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .help("Only list files at least this big")
            }

            Divider()

            Table(rows, selection: $highlighted, sortOrder: $sortOrder) {
                TableColumn("") { item in
                    Toggle("Select \(item.name)", isOn: Binding(
                        get: { model.isSelected(item) },
                        set: { model.setSelected(item, $0) }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                }
                .width(22)

                TableColumn("Name", value: \.name) { item in
                    HStack(spacing: Theme.Spacing.s) {
                        ItemIcon(item: item, size: 18)
                        Text(item.name).lineLimit(1).truncationMode(.middle)
                    }
                }
                .width(min: 180, ideal: 280)

                TableColumn("Kind") { item in
                    Text(item.section ?? "Document").foregroundStyle(.secondary).lineLimit(1)
                }
                .width(min: 80, ideal: 120)

                TableColumn("Location", value: \.detail) { item in
                    Text(item.detail).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                }
                .width(min: 100, ideal: 180)

                TableColumn("Modified", value: \.sortDate) { item in
                    Text(item.lastModified?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .width(min: 90, ideal: 110)

                TableColumn("Size", value: \.size) { item in
                    Text(item.size.byteString)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 70, ideal: 90)
            }
            .contextMenu(forSelectionType: CleanableItem.ID.self) { ids in
                let targets = rows.filter { ids.contains($0.id) }
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(targets.map(\.url)) }
                Button("Select for Cleanup") { model.setSelected(targets, true) }
                Button("Deselect") { model.setSelected(targets, false) }
                if targets.count == 1, let item = targets.first {
                    Divider()
                    Button("Never Show This File Again") { model.exclude(item) }
                }
            } primaryAction: { ids in
                NSWorkspace.shared.activateFileViewerSelecting(rows.filter { ids.contains($0.id) }.map(\.url))
            }
            .overlay { emptyState(isEmpty: rows.isEmpty) }

            CleanBar(categories: [.largeFiles])
        }
        .navigationTitle("Large Files")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search Large Files")
    }

    @ViewBuilder
    private func emptyState(isEmpty: Bool) -> some View {
        if isEmpty {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if model.isScanning(.largeFiles) {
                ProgressView("Looking for large files…")
            } else if !model.isScanned(.largeFiles) {
                ContentUnavailableView {
                    Label("Not scanned yet", systemImage: CleanCategory.largeFiles.symbol)
                } description: {
                    Text(CleanCategory.largeFiles.summary)
                } actions: {
                    Button("Scan Now") { model.startScan() }.buttonStyle(.primary)
                }
            } else {
                ContentUnavailableView(
                    "No large files",
                    systemImage: "checkmark.seal",
                    description: Text("Nothing bigger than \(model.preferences.largeFileThreshold.byteString) in Downloads, Desktop, Documents or Movies.")
                )
            }
        }
    }
}

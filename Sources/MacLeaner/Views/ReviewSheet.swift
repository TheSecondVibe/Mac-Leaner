import AppKit
import SwiftUI

/// Shown before anything is removed: exactly what happens to each item.
struct ReviewSheet: View {
    let request: ReviewRequest

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let permanent = request.permanent
        let trashed = request.trashed
        let runningApps = runningAppNames

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.brandGradient)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title2.weight(.bold))
                    Text("Check what will happen before anything is removed.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding([.horizontal, .top], Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.l)

            HStack(spacing: Theme.Spacing.m) {
                if !permanent.isEmpty {
                    SummaryTile(
                        title: "Deleted permanently",
                        subtitle: "Caches and logs that rebuild themselves",
                        items: permanent,
                        symbol: "trash.slash.fill",
                        tint: Theme.destructive
                    )
                }
                if !trashed.isEmpty {
                    SummaryTile(
                        title: "Moved to Trash",
                        subtitle: "You can put these back from the Trash",
                        items: trashed,
                        symbol: "arrow.uturn.backward.circle.fill",
                        tint: Theme.accent
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            if !runningApps.isEmpty {
                Label {
                    Text(runningApps.count == 1
                        ? "Quit \(runningApps[0]) first, so it doesn't write new files while its data is removed."
                        : "Quit \(ListFormatter.localizedString(byJoining: runningApps)) first, so they don't write new files while their data is removed.")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.caution)
                }
                .font(.callout)
                .padding(Theme.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous).fill(Theme.caution.opacity(0.12)))
                .padding([.horizontal, .top], Theme.Spacing.xl)
            }

            List {
                if !permanent.isEmpty {
                    Section("Deleted permanently") { ForEach(permanent) { ReviewRow(item: $0) } }
                }
                if !trashed.isEmpty {
                    Section("Moved to Trash") { ForEach(trashed) { ReviewRow(item: $0) } }
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 160, idealHeight: 280, maxHeight: 320)
            .padding(.top, Theme.Spacing.m)

            Divider()

            HStack(spacing: Theme.Spacing.m) {
                if !permanent.isEmpty {
                    Label("Permanent deletions can't be undone.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(confirmTitle) { model.clean(request) }
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(Theme.Spacing.l)
        }
        .frame(width: 600)
    }

    private var isTrashOnly: Bool { request.permanent.isEmpty }

    private var title: String {
        isTrashOnly ? "Move \(request.totalSize.byteString) to the Trash?" : "Clean \(request.totalSize.byteString)?"
    }

    private var confirmTitle: String {
        isTrashOnly ? "Move to Trash" : "Clean \(request.totalSize.byteString)"
    }

    private var runningAppNames: [String] {
        Set(request.items.compactMap(\.ownerBundleID))
            .compactMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0).first?.localizedName }
            .sorted()
    }
}

private struct SummaryTile: View {
    let title: String
    let subtitle: String
    let items: [CleanableItem]
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(items.reduce(0) { $0 + $1.size }.byteString)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text("\(title) · \(items.count) \(items.count == 1 ? "item" : "items")")
                    .font(.callout.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(tint.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).strokeBorder(tint.opacity(0.25)))
        .accessibilityElement(children: .combine)
    }
}

private struct ReviewRow: View {
    let item: CleanableItem

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ItemIcon(item: item, size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).lineLimit(1)
                Text(item.category.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.size.byteString)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

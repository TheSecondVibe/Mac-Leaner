import AppKit
import SwiftUI

/// Caches app and file icons so list rows don't hit Launch Services on every render.
@MainActor
final class IconCache {
    static let shared = IconCache()
    private let cache = NSCache<NSString, NSImage>()
    private var misses: Set<String> = []

    func icon(for item: CleanableItem) -> NSImage? {
        let key = item.ownerBundleID ?? item.id
        if let cached = cache.object(forKey: key as NSString) { return cached }
        if misses.contains(key) { return nil }

        var image: NSImage?
        if let owner = item.ownerBundleID, let app = AppDirectory.appURL(for: owner) {
            image = NSWorkspace.shared.icon(forFile: app.path)
        } else if FileManager.default.fileExists(atPath: item.url.path) {
            image = NSWorkspace.shared.icon(forFile: item.url.path)
        }
        if let image {
            cache.setObject(image, forKey: key as NSString)
        } else {
            misses.insert(key)
        }
        return image
    }
}

struct ItemIcon: View {
    let item: CleanableItem
    var size: CGFloat = 28

    var body: some View {
        if let image = IconCache.shared.icon(for: item) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            IconTile(symbol: item.isDirectory ? "folder.fill" : "doc.fill", tint: item.category.tint, size: size)
        }
    }
}

/// Says in plain words what cleaning an item does.
struct ActionBadge: View {
    let item: CleanableItem

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(color)
            .labelStyle(.titleAndIcon)
    }

    private var text: String {
        switch item.action {
        case .delete, .emptyContents: item.safety == .safe ? "Rebuilt automatically" : "Deleted permanently"
        case .moveToTrash: "Moves to Trash"
        case .none: "Manual cleanup"
        }
    }

    private var symbol: String {
        switch item.action {
        case .delete, .emptyContents: item.safety == .safe ? "arrow.triangle.2.circlepath" : "exclamationmark.triangle.fill"
        case .moveToTrash: "arrow.uturn.backward.circle"
        case .none: "hand.raised"
        }
    }

    private var color: Color {
        switch item.action {
        case .delete, .emptyContents: item.safety == .safe ? Theme.positive : Theme.caution
        case .moveToTrash: .secondary
        case .none: Theme.accent
        }
    }
}

struct ItemRow: View {
    let item: CleanableItem
    let maxSize: Int64

    @Environment(AppModel.self) private var model
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            if item.isCleanable {
                Toggle("Select \(item.name)", isOn: Binding(
                    get: { model.isSelected(item) },
                    set: { model.setSelected(item, $0) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
            } else {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                    .help("Mac-Leaner can't clean this directly")
                    .accessibilityHidden(true)
            }

            ItemIcon(item: item)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(item.hint ?? item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Spacing.m) {
                    ActionBadge(item: item)
                    if let date = item.lastModified {
                        Text("Modified \(date, format: .relative(presentation: .named))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: Theme.Spacing.m)

            VStack(alignment: .trailing, spacing: 5) {
                Text(item.size.byteString)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                SizeBar(fraction: maxSize > 0 ? Double(item.size) / Double(maxSize) : 0, tint: item.category.tint)
                    .frame(width: 72)
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .opacity(isHovering ? 1 : 0.4)
            .help("Show in Finder")
            .accessibilityLabel("Show \(item.name) in Finder")
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu { ItemContextMenu(item: item) }
    }
}

struct ItemContextMenu: View {
    let item: CleanableItem
    @Environment(AppModel.self) private var model

    var body: some View {
        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }
        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.url.path, forType: .string)
        }
        Divider()
        Button("Never Show This Location Again") {
            model.exclude(item)
        }
    }
}

struct FullDiskAccessBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            IconTile(symbol: "lock.shield.fill", tint: Theme.caution, size: 34)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Allow Full Disk Access to see everything")
                    .font(.headline)
                Text("macOS hides the Trash, virtual machines and some app data from apps without it. Mac-Leaner only reads these locations, and nothing ever leaves your Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Spacing.s) {
                    Button("Open Privacy Settings") { Permissions.openFullDiskAccessSettings() }
                    Button("Check Again") { model.refreshPermissions() }
                }
                .padding(.top, Theme.Spacing.xs)
            }
            Spacer(minLength: 0)
        }
        .card()
    }
}

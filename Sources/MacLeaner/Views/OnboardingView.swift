import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            BrandMark(size: 96)

            VStack(spacing: 6) {
                Text("Welcome to Mac-Leaner")
                    .font(.largeTitle.weight(.bold))
                Text("A careful way to get your disk space back.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                FeatureRow(
                    symbol: "checkmark.shield.fill", tint: Theme.positive, title: "Safe by default",
                    text: "Only caches, logs and build products are preselected. Your own files only ever go to the Trash."
                )
                FeatureRow(
                    symbol: "eye.fill", tint: Theme.accent, title: "You review everything",
                    text: "Nothing is removed until you've seen exactly what will happen to it."
                )
                FeatureRow(
                    symbol: "lock.fill", tint: Theme.indigo, title: "Private",
                    text: "Mac-Leaner works entirely offline. Nothing about your files leaves your Mac."
                )
            }
            .padding(Theme.Spacing.l)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(Color.primary.opacity(0.04)))

            if !model.hasFullDiskAccess {
                HStack(spacing: Theme.Spacing.s) {
                    Text("Optional: allow Full Disk Access to include the Trash and virtual machines.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") { Permissions.openFullDiskAccessSettings() }
                        .controlSize(.small)
                }
            }

            HStack(spacing: Theme.Spacing.m) {
                Button("Not Now") { model.completeOnboarding(startScanning: false) }
                    .keyboardShortcut(.cancelAction)
                Button("Start First Scan") { model.completeOnboarding(startScanning: true) }
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(40)
        .frame(width: 540)
        .interactiveDismissDisabled()
    }
}

private struct FeatureRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            IconTile(symbol: symbol, tint: tint, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

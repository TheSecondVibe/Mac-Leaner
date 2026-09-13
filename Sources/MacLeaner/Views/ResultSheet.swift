import AppKit
import SwiftUI

/// What actually happened, including anything that couldn't be cleaned.
struct ResultSheet: View {
    let report: CleanReport

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var hasFailures: Bool { !report.failures.isEmpty }
    private var tint: Color { hasFailures ? Theme.caution : Theme.positive }

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 84, height: 84)
                Image(systemName: hasFailures ? "exclamationmark" : "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(tint)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.4)
                    .opacity(appeared || reduceMotion ? 1 : 0)
            }
            .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.xs) {
                Text(headline)
                    .font(.title2.weight(.bold))
                Text(subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: Theme.Spacing.m) {
                ResultStat(value: report.freedBytes.byteString, label: "Freed", tint: Theme.positive)
                if report.trashedBytes > 0 {
                    ResultStat(value: report.trashedBytes.byteString, label: "Moved to Trash", tint: Theme.accent)
                }
                ResultStat(value: report.availableAfter.byteString, label: "Now available", tint: .primary)
            }

            if report.trashedBytes > 0 {
                HStack(spacing: Theme.Spacing.s) {
                    Text("Items in the Trash use space until you empty it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Open Trash") {
                        NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash"))
                    }
                }
            }

            if hasFailures {
                DisclosureGroup("\(report.failures.count) \(report.failures.count == 1 ? "item" : "items") couldn't be cleaned") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            ForEach(report.failures) { failure in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(failure.name).font(.callout.weight(.medium))
                                    Text(failure.reason).font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.top, Theme.Spacing.s)
                    }
                    .frame(maxHeight: 150)
                }
                .padding(Theme.Spacing.m)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous).fill(Theme.caution.opacity(0.1)))
            }

            Button("Done") { dismiss() }
                .buttonStyle(.primary)
                .keyboardShortcut(.defaultAction)
                .padding(.top, Theme.Spacing.xs)
        }
        .padding(28)
        .frame(width: 460)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.05)) { appeared = true }
        }
    }

    private var headline: String {
        if report.cleanedCount == 0 && hasFailures { return "Nothing could be cleaned" }
        if report.freedBytes > 0 { return "Freed \(report.freedBytes.byteString)" }
        if report.trashedBytes > 0 { return "Moved \(report.trashedBytes.byteString) to the Trash" }
        return "All done"
    }

    private var subheadline: String {
        var text = "\(report.cleanedCount) \(report.cleanedCount == 1 ? "item" : "items") cleaned."
        if hasFailures {
            text += " Some items were skipped; see the details below."
        } else if report.freedBytes > 1_000_000_000, report.availableDelta < report.freedBytes / 2 {
            // APFS can keep freed blocks in local Time Machine snapshots for a while.
            text += " Some space may stay reserved by Time Machine snapshots until macOS releases it."
        }
        return text
    }
}

private struct ResultStat: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.m)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(Color.primary.opacity(0.05)))
        .accessibilityElement(children: .combine)
    }
}

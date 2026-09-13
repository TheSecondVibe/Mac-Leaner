import SwiftUI

/// The brand's storage ring: used space in indigo→azure, with the part that
/// can be cleaned highlighted in mint, like the app icon.
struct StorageRing: View {
    /// Fraction of the disk in use (0...1).
    let usage: Double
    /// Fraction of the disk that can be cleaned (a subset of `usage`).
    let cleanable: Double
    var lineWidth: CGFloat = 18
    var trackColor: Color = .white.opacity(0.1)
    var isScanning = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweepAngle: Double = -90

    private var usedEnd: Double { min(1, max(0, usage)) }
    private var cleanableStart: Double { max(0, usedEnd - min(max(0, cleanable), usedEnd)) }

    var body: some View {
        ZStack {
            Circle().stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: cleanableStart)
                .stroke(
                    AngularGradient(colors: [Theme.indigo, Theme.azure], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(cleanableStart, 0.01))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: cleanableStart, to: usedEnd)
                .stroke(Theme.mint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.mint.opacity(0.55), radius: lineWidth / 3)

            if isScanning && !reduceMotion {
                Circle()
                    .trim(from: 0, to: 0.1)
                    .stroke(.white.opacity(0.6), style: StrokeStyle(lineWidth: lineWidth * 0.3, lineCap: .round))
                    .rotationEffect(.degrees(sweepAngle))
                    .onAppear {
                        withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) { sweepAngle = 270 }
                    }
                    .onDisappear { sweepAngle = -90 }
            }
        }
        .padding(lineWidth / 2)
        .animation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.85), value: usage)
        .animation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.85), value: cleanable)
        .accessibilityElement()
        .accessibilityLabel("Disk usage")
        .accessibilityValue("\(Int(usedEnd * 100)) percent used, \(Int(min(cleanable, usedEnd) * 100)) percent can be cleaned")
    }
}

/// A thin proportional bar used next to sizes in lists.
struct SizeBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(3, geometry.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

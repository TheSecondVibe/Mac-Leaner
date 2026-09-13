import SwiftUI

/// Four-point sparkle from the app icon.
struct Sparkle: Shape {
    var pinch: CGFloat = 0.14

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        func control(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
            CGPoint(x: center.x + dx * rect.width / 2 * pinch, y: center.y + dy * rect.height / 2 * pinch)
        }
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: center.y), control: control(1, -1))
        path.addQuadCurve(to: CGPoint(x: center.x, y: rect.maxY), control: control(1, 1))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: center.y), control: control(-1, 1))
        path.addQuadCurve(to: CGPoint(x: center.x, y: rect.minY), control: control(-1, -1))
        path.closeSubpath()
        return path
    }
}

/// The app icon drawn in SwiftUI, so it looks right even when running unbundled
/// (`swift run`). Proportions match `scripts/make_icon.swift`.
struct BrandMark: View {
    var size: CGFloat = 64

    var body: some View {
        let unit = size / 824
        let gap = 0.16
        ZStack {
            RoundedRectangle(cornerRadius: 185 * unit, style: .continuous)
                .fill(LinearGradient(colors: [Theme.navyLight, Theme.navy], startPoint: .top, endPoint: .bottom))

            Circle()
                .trim(from: 0, to: 1 - gap)
                .stroke(
                    AngularGradient(
                        colors: [Theme.indigo, Theme.azure, Theme.mint],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * (1 - gap))
                    ),
                    style: StrokeStyle(lineWidth: 92 * unit, lineCap: .round)
                )
                .rotationEffect(.degrees(-45 + 180 * gap))
                .frame(width: 480 * unit, height: 480 * unit)
                .position(x: 390 * unit, y: 440 * unit)

            Sparkle()
                .fill(.white)
                .frame(width: 300 * unit, height: 300 * unit)
                .shadow(color: Theme.mint.opacity(0.8), radius: 24 * unit)
                .position(x: 560 * unit, y: 270 * unit)

            Sparkle()
                .fill(.white.opacity(0.92))
                .frame(width: 92 * unit, height: 92 * unit)
                .position(x: 706 * unit, y: 122 * unit)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.2), radius: size * 0.04, y: size * 0.02)
        .accessibilityHidden(true)
    }
}

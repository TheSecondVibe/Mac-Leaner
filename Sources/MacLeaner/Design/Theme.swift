import AppKit
import SwiftUI

/// Design tokens. Brand colors come from the app icon; semantic colors are
/// tuned per appearance so text on them keeps at least 4.5:1 contrast.
enum Theme {
    // Brand
    static let navy = Color(hex: 0x0B1030)
    static let navyLight = Color(hex: 0x1E2D63)
    static let indigo = Color(hex: 0x4B3FE0)
    static let azure = Color(hex: 0x2A9DF4)
    static let mint = Color(hex: 0x4FF0C8)

    // Semantic
    static let accent = Color(light: 0x3346D3, dark: 0x7B8CFF)
    static let positive = Color(light: 0x15803D, dark: 0x4ADE80)
    static let caution = Color(light: 0xB45309, dark: 0xFBBF24)
    static let destructive = Color(light: 0xDC2626, dark: 0xF87171)

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [indigo, azure, mint], startPoint: .leading, endPoint: .trailing)
    }
    static var buttonGradient: LinearGradient {
        LinearGradient(colors: [indigo, Color(hex: 0x2563EB)], startPoint: .leading, endPoint: .trailing)
    }
    static var heroGradient: LinearGradient {
        LinearGradient(colors: [navyLight, navy], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let tile: CGFloat = 8
        static let card: CGFloat = 14
        static let hero: CGFloat = 20
    }

    static let contentMaxWidth: CGFloat = 980
}

extension Color {
    init(hex: UInt32) {
        self.init(nsColor: NSColor(hex: hex))
    }

    /// A color that switches with the system appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Button styles

/// The one prominent action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    var role: ButtonRole?
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, 7)
            .background {
                if role == .destructive {
                    Capsule().fill(Color(hex: 0xDC2626))
                } else {
                    Capsule().fill(Theme.buttonGradient)
                }
            }
            .overlay(Capsule().strokeBorder(.white.opacity(0.18)))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Secondary action on the dark hero panel.
struct GlassButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, 7)
            .background(Capsule().fill(.white.opacity(configuration.isPressed ? 0.24 : 0.14)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.2)))
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var primaryDestructive: PrimaryButtonStyle { PrimaryButtonStyle(role: .destructive) }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle() }
}

// MARK: - Surfaces

extension View {
    /// A raised surface used for grouped content.
    func card(padding: CGFloat = Theme.Spacing.l) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07))
            )
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

/// Rounded tinted square holding a category symbol.
struct IconTile: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(tint.opacity(0.15))
            )
            .accessibilityHidden(true)
    }
}

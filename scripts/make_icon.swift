#!/usr/bin/env swift
//
// Renders the MacLean app icon and packages it as Assets/AppIcon.icns,
// plus a 1024px Assets/AppIcon.png for docs.
//
// Usage (from the project root):  swift scripts/make_icon.swift
//
// The artwork follows Apple's macOS icon grid: a 1024pt canvas with an
// 824pt continuous-corner body, so it sits correctly next to system icons.

import AppKit
import SwiftUI

// MARK: - Artwork

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Four-point sparkle, the same motif as the menu bar's `sparkles` glyph.
struct Sparkle: Shape {
    /// 0 = needle-thin arms; larger = chunkier star body.
    var pinch: CGFloat = 0.14

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        func control(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
            CGPoint(x: c.x + dx * rect.width / 2 * pinch, y: c.y + dy * rect.height / 2 * pinch)
        }
        var path = Path()
        path.move(to: CGPoint(x: c.x, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: c.y), control: control(1, -1))
        path.addQuadCurve(to: CGPoint(x: c.x, y: rect.maxY), control: control(1, 1))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: c.y), control: control(-1, 1))
        path.addQuadCurve(to: CGPoint(x: c.x, y: rect.minY), control: control(-1, -1))
        path.closeSubpath()
        return path
    }
}

/// A storage ring with a gap swept clean by a sparkle: lean storage.
struct AppIconArtwork: View {
    private let ringCenter = CGPoint(x: 490, y: 540)
    private let ringRadius: CGFloat = 240
    private let ringWidth: CGFloat = 92
    private let gapFraction = 0.16   // share of the ring the sparkle has cleared
    private let gapAngle = -45.0     // degrees; 0 = 3 o'clock, negative = counter-clockwise

    private var sparkleCenter: CGPoint {
        let a = gapAngle * .pi / 180
        return CGPoint(x: ringCenter.x + ringRadius * cos(a), y: ringCenter.y + ringRadius * sin(a))
    }

    var body: some View {
        ZStack {
            plate

            // Faint full track, so the ring still reads as a capacity gauge.
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: ringWidth)
                .frame(width: ringRadius * 2, height: ringRadius * 2)
                .position(ringCenter)

            // Used-space arc, brightening toward the sparkle like a sweep.
            Circle()
                .trim(from: 0, to: 1 - gapFraction)
                .stroke(
                    AngularGradient(
                        colors: [Color(hex: 0x4B3FE0), Color(hex: 0x2A9DF4), Color(hex: 0x4FF0C8)],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * (1 - gapFraction))
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(gapAngle + 180 * gapFraction))
                .frame(width: ringRadius * 2, height: ringRadius * 2)
                .position(ringCenter)

            Sparkle()
                .fill(Color.white)
                .frame(width: 300, height: 300)
                .shadow(color: Color(hex: 0x6FF5D2).opacity(0.85), radius: 28)
                .shadow(color: Color.white.opacity(0.5), radius: 6)
                .position(sparkleCenter)

            Sparkle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 92, height: 92)
                .shadow(color: Color(hex: 0x6FF5D2).opacity(0.7), radius: 12)
                .position(x: 806, y: 222)
        }
        .frame(width: 1024, height: 1024)
    }

    private var plate: some View {
        let shape = RoundedRectangle(cornerRadius: 185, style: .continuous)
        return shape
            .fill(LinearGradient(colors: [Color(hex: 0x1E2D63), Color(hex: 0x0B1030)], startPoint: .top, endPoint: .bottom))
            .overlay(
                shape.fill(RadialGradient(
                    colors: [Color.white.opacity(0.14), .clear],
                    center: UnitPoint(x: 0.5, y: 0),
                    startRadius: 0,
                    endRadius: 620
                ))
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center),
                    lineWidth: 3
                )
            )
            .frame(width: 824, height: 824)
            .shadow(color: .black.opacity(0.35), radius: 14, y: 10)
    }
}

// MARK: - Rendering

@MainActor
func pngData(pixels: Int) -> Data {
    let renderer = ImageRenderer(content: AppIconArtwork())
    renderer.scale = CGFloat(pixels) / 1024
    guard let cgImage = renderer.cgImage,
          let data = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
        fatalError("Failed to render icon at \(pixels)px")
    }
    return data
}

let projectRoot = URL(fileURLWithPath: #filePath).standardizedFileURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let assetsDir = projectRoot.appendingPathComponent("Assets")
let iconsetDir = FileManager.default.temporaryDirectory.appendingPathComponent("MacLean-AppIcon.iconset")

try? FileManager.default.removeItem(at: iconsetDir)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

try MainActor.assumeIsolated {
    for variant in variants {
        try pngData(pixels: variant.pixels).write(to: iconsetDir.appendingPathComponent("\(variant.name).png"))
    }
    try pngData(pixels: 1024).write(to: assetsDir.appendingPathComponent("AppIcon.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetDir.path, "-o", assetsDir.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed with status \(iconutil.terminationStatus)") }
try? FileManager.default.removeItem(at: iconsetDir)

print("✅ Wrote Assets/AppIcon.icns and Assets/AppIcon.png")

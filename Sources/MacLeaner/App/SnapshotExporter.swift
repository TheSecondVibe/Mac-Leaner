import AppKit
import SwiftUI

/// Renders README screenshots from demo data:
///
///     swift run MacLeaner --demo --snapshot docs/screenshots
///
/// Only demo data (never real files) can end up in a screenshot.
@MainActor
enum SnapshotExporter {
    static var outputFolder: URL? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--snapshot"), arguments.indices.contains(index + 1) else { return nil }
        return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
    }

    static func run(model: AppModel) async {
        guard model.isDemo, let folder = outputFolder else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        await pause(1)
        while model.isScanning { await pause(0.2) }
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain && !($0 is NSPanel) }) else {
            exit(1)
        }
        window.setContentSize(NSSize(width: 1180, height: 780))
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)

        NSApp.appearance = NSAppearance(named: .aqua)
        for (route, name) in [
            (Route.overview, "overview"),
            (.category(.appCaches), "app-caches"),
            (.category(.systemData), "system-data"),
            (.category(.largeFiles), "large-files"),
        ] {
            model.route = route
            await pause(1)
            capture(window, to: folder.appendingPathComponent("\(name).png"))
        }

        NSApp.appearance = NSAppearance(named: .darkAqua)
        model.route = .overview
        await pause(1)
        capture(window, to: folder.appendingPathComponent("overview-dark.png"))

        NSApp.appearance = NSAppearance(named: .aqua)
        await pause(0.5)
        await saveMenuBarPanel(model: model, appearance: .aqua, to: folder.appendingPathComponent("menubar.png"))
        await saveMenuBarPanel(model: model, appearance: .darkAqua, to: folder.appendingPathComponent("menubar-dark.png"))

        model.reviewSelection()
        await pause(1.2)
        if let sheet = window.attachedSheet { cacheDisplay(sheet, to: folder.appendingPathComponent("review.png")) }
        if let request = model.reviewRequest { model.clean(request) }
        await pause(1.5)
        if let sheet = window.attachedSheet { cacheDisplay(sheet, to: folder.appendingPathComponent("results.png")) }

        // A presented sheet can hold up NSApp.terminate; this is a dev tool, so just exit.
        exit(0)
    }

    /// Prefers the window server's picture of the window, which includes Liquid Glass
    /// and scroll content that in-process rendering can't see.
    private static func capture(_ window: NSWindow, to url: URL) {
        if let image = windowServerImage(of: window) {
            try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: url)
        } else {
            renderLayers(of: window, to: url)
        }
    }

    /// `CGWindowListCreateImage` is unavailable in recent SDKs, so it's looked up at
    /// runtime. A process may capture its own windows without screen-recording access.
    private static func windowServerImage(of window: NSWindow) -> CGImage? {
        typealias CreateImage = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY),
              let symbol = dlsym(handle, "CGWindowListCreateImage") else { return nil }
        let create = unsafeBitCast(symbol, to: CreateImage.self)
        let includingWindow: UInt32 = 1 << 3
        let ignoreFramingAtBestResolution: UInt32 = (1 << 0) | (1 << 3)
        return create(.null, includingWindow, UInt32(window.windowNumber), ignoreFramingAtBestResolution)?.takeRetainedValue()
    }

    /// Fallback: render the window's layer tree over its background color.
    private static func renderLayers(of window: NSWindow, to url: URL) {
        guard let view = window.contentView?.superview ?? window.contentView, let layer = view.layer else { return }
        let bounds = view.bounds
        let scale = window.backingScaleFactor
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)
        guard width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return }

        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            context.setFillColor(NSColor.windowBackgroundColor.cgColor)
        }
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        if layer.isGeometryFlipped {
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
        }
        layer.render(in: context)
        guard let image = context.makeImage() else { return }
        try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: url)
    }

    /// Drawing-based capture, which suits sheets and the menu bar panel.
    private static func cacheDisplay(_ window: NSWindow, to url: URL) {
        guard let view = window.contentView?.superview ?? window.contentView else { return }
        cacheDisplay(view, to: url)
    }

    private static func cacheDisplay(_ view: NSView, to url: URL) {
        let bounds = view.bounds
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        view.cacheDisplay(in: bounds, to: bitmap)
        try? bitmap.representation(using: .png, properties: [:])?.write(to: url)
    }

    private static func saveMenuBarPanel(model: AppModel, appearance: NSAppearance.Name, to url: URL) async {
        let hosting = NSHostingView(rootView:
            MenuBarPanel()
                .environment(model)
                .tint(Theme.accent)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        )
        hosting.appearance = NSAppearance(named: appearance)
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        let panel = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView = hosting
        panel.setFrameOrigin(NSPoint(x: -5000, y: -5000))
        panel.orderFrontRegardless()
        await pause(0.8)
        cacheDisplay(hosting, to: url)
        panel.orderOut(nil)
    }

    private static func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}

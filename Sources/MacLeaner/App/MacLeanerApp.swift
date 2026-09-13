import AppKit
import SwiftUI

enum AppLinks {
    static let repository = URL(string: "https://github.com/TheSecondVibe/Mac-Leaner")!
    static let issues = URL(string: "https://github.com/TheSecondVibe/Mac-Leaner/issues")!
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Mac-Leaner keeps running in the menu bar when its window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct MacLeanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel(
        preferences: Preferences(),
        isDemo: CommandLine.arguments.contains("--demo")
    )

    var body: some Scene {
        Window("Mac-Leaner", id: "main") {
            RootView()
                .environment(model)
                .tint(Theme.accent)
        }
        .defaultSize(width: 1080, height: 740)
        .windowToolbarStyle(.unified)
        .commands { AppCommands(model: model) }

        MenuBarExtra {
            MenuBarPanel()
                .environment(model)
                .tint(Theme.accent)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
                .tint(Theme.accent)
        }
    }
}

private struct AppCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
        CommandMenu("Cleanup") {
            Button("Scan") { model.startScan() }
                .keyboardShortcut("r")
                .disabled(model.isScanning || model.isCleaning)
            Button("Stop Scan") { model.cancelScan() }
                .keyboardShortcut(".")
                .disabled(!model.isScanning)
            Divider()
            Button("Review & Clean…") { model.reviewSelection() }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .disabled(model.selectedTotal == 0 || model.isScanning || model.isCleaning)
        }
        CommandGroup(replacing: .help) {
            Link("Mac-Leaner on GitHub", destination: AppLinks.repository)
            Link("Report an Issue", destination: AppLinks.issues)
        }
    }
}

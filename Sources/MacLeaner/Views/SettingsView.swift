import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }
            ScanningSettings().tabItem { Label("Scanning", systemImage: "magnifyingglass") }
            ExclusionsSettings().tabItem { Label("Exclusions", systemImage: "eye.slash") }
            AboutSettings().tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 540)
    }
}

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    @State private var launchesAtLogin = false
    @State private var loginError: String?

    var body: some View {
        @Bindable var preferences = model.preferences

        Form {
            Section {
                Toggle("Show Mac-Leaner in the Dock", isOn: $preferences.showInDock)
                Toggle("Show the selected size in the menu bar", isOn: $preferences.showSizeInMenuBar)
                Toggle("Scan when Mac-Leaner opens", isOn: $preferences.scanOnLaunch)
                Toggle("Open at login", isOn: $launchesAtLogin)
                    .onChange(of: launchesAtLogin) { _, enabled in updateLoginItem(enabled) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(Theme.destructive)
                }
            }

            Section("Permissions") {
                LabeledContent("Full Disk Access") {
                    HStack(spacing: Theme.Spacing.s) {
                        Label(
                            model.hasFullDiskAccess ? "Allowed" : "Not allowed",
                            systemImage: model.hasFullDiskAccess ? "checkmark.circle.fill" : "xmark.circle"
                        )
                        .foregroundStyle(model.hasFullDiskAccess ? Theme.positive : .secondary)
                        if !model.hasFullDiskAccess {
                            Button("Open Settings") { Permissions.openFullDiskAccessSettings() }
                        }
                    }
                }
                Text("Needed to include the Trash, virtual machines and data inside other apps' containers. Mac-Leaner never sends anything off your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchesAtLogin = model.preferences.launchesAtLogin
            model.refreshPermissions()
        }
    }

    private func updateLoginItem(_ enabled: Bool) {
        guard enabled != model.preferences.launchesAtLogin else { return }
        do {
            try model.preferences.setLaunchesAtLogin(enabled)
            loginError = nil
        } catch {
            loginError = "Couldn't change the login item: \(error.localizedDescription)"
            launchesAtLogin = model.preferences.launchesAtLogin
        }
    }
}

private struct ScanningSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var preferences = model.preferences

        Form {
            Section("Large Files") {
                Picker("List files larger than", selection: $preferences.largeFileThresholdMB) {
                    ForEach(Preferences.largeFileThresholds, id: \.self) { megabytes in
                        Text((Int64(megabytes) * 1_000_000).byteString).tag(megabytes)
                    }
                }
                Text("Mac-Leaner looks in Downloads, Desktop, Documents and Movies.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("App Leftovers") {
                Picker("Only list folders unchanged for", selection: $preferences.leftoverIdleDays) {
                    ForEach([30, 60, 90, 180, 365], id: \.self) { days in
                        Text(days == 365 ? "1 year" : "\(days) days").tag(days)
                    }
                }
                Text("A folder an app wrote to recently is never listed, because something still uses it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ExclusionsSettings: View {
    @Environment(AppModel.self) private var model
    @State private var selection: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Mac-Leaner never shows or cleans these locations, or anything inside them.")
                .foregroundStyle(.secondary)

            List(selection: $selection) {
                ForEach(model.preferences.excludedPaths, id: \.self) { path in
                    Label(
                        path.replacingOccurrences(of: NSHomeDirectory(), with: "~", options: .anchored),
                        systemImage: "folder"
                    )
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .frame(minHeight: 200)
            .overlay {
                if model.preferences.excludedPaths.isEmpty {
                    Text("No exclusions. Right-click any item and choose “Never Show This Location Again”.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }

            HStack(spacing: Theme.Spacing.s) {
                Button { addLocations() } label: { Label("Add…", systemImage: "plus") }
                Button {
                    if let selection { model.removeExclusion(selection) }
                    selection = nil
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(selection == nil)
                Spacer()
            }
        }
        .padding(Theme.Spacing.xl)
    }

    private func addLocations() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.prompt = "Exclude"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            model.excludePath(url.path)
        }
    }
}

private struct AboutSettings: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development build"
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            BrandMark(size: 80)
            Text("Mac-Leaner").font(.title.weight(.bold))
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("A safe, native storage cleaner for macOS. Free and open source under the MIT License.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Spacing.s) {
                Link("GitHub", destination: AppLinks.repository)
                Text("·").foregroundStyle(.tertiary)
                Link("Report an Issue", destination: AppLinks.issues)
            }
        }
        .padding(Theme.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

import AppKit

/// Wrappers around the command-line tools Mac-Leaner uses. Results are passed
/// through unchanged so the UI can report exactly what happened.
enum SystemTools {
    struct Output: Sendable {
        let status: Int32
        let text: String
        var succeeded: Bool { status == 0 }
    }

    static func run(_ executable: String, _ arguments: [String]) async -> Output {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                    // Read before waiting so a full pipe can't block the process.
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: Output(status: process.terminationStatus, text: text))
                } catch {
                    continuation.resume(returning: Output(status: -1, text: error.localizedDescription))
                }
            }
        }
    }

    /// `simctl` ships with Xcode, not with the Command Line Tools.
    static func simulatorToolsAvailable() async -> Bool {
        await run("/usr/bin/xcrun", ["--find", "simctl"]).succeeded
    }

    static func pruneUnavailableSimulators() async -> Output {
        await run("/usr/bin/xcrun", ["simctl", "delete", "unavailable"])
    }

    static func localSnapshotCount() async -> Int? {
        let output = await run("/usr/bin/tmutil", ["listlocalsnapshots", "/"])
        guard output.succeeded else { return nil }
        return output.text.split(separator: "\n").filter { $0.contains("com.apple.TimeMachine") }.count
    }

    /// Asks macOS to release as much space held by local Time Machine snapshots as it can.
    static func thinLocalSnapshots() async -> Output {
        await run("/usr/bin/tmutil", ["thinlocalsnapshots", "/", "999999999999999", "4"])
    }
}

enum Permissions {
    /// macOS has no API for this. Listing the Trash only works with Full Disk Access.
    static var hasFullDiskAccess: Bool {
        let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        return (try? FileManager.default.contentsOfDirectory(atPath: trash.path)) != nil
    }

    @MainActor
    static func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }
}

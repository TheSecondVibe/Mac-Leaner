import Foundation

enum CleanError: LocalizedError {
    case partiallyEmptied(failed: Int, total: Int, reason: String)

    var errorDescription: String? {
        switch self {
        case let .partiallyEmptied(failed, total, reason):
            "\(failed) of \(total) items inside couldn't be removed. \(reason)"
        }
    }
}

/// Performs the actions the user reviewed and reports exactly what happened.
struct CleanerEngine: Sendable {
    let policy: SafetyPolicy

    func clean(_ items: [CleanableItem]) async -> CleanReport {
        var report = CleanReport()
        report.availableBefore = SystemMetrics.availableDiskSpace(at: policy.home)
        for item in items {
            if Task.isCancelled { break }
            do {
                // Act on the canonical path the policy approved, never on the raw item URL.
                let target = try policy.validate(item)
                try perform(item, at: target, into: &report)
                report.cleanedIDs.append(item.id)
            } catch {
                report.failures.append(.init(name: item.name, path: item.url.path, reason: error.localizedDescription))
            }
        }
        report.availableAfter = SystemMetrics.availableDiskSpace(at: policy.home)
        return report
    }

    private func perform(_ item: CleanableItem, at target: URL, into report: inout CleanReport) throws {
        let fileManager = FileManager.default
        // Already gone (for example removed by its app): nothing left to do.
        guard (try? fileManager.attributesOfItem(atPath: target.path)) != nil else { return }

        switch item.action {
        case .none:
            throw SafetyPolicy.Violation.informational

        case .moveToTrash:
            var landed: NSURL?
            try fileManager.trashItem(at: target, resultingItemURL: &landed)
            report.trashedBytes += item.size
            if let path = landed?.path { report.trashedPaths.append(path) }

        case .delete:
            do {
                try fileManager.removeItem(at: target)
                report.freedBytes += item.size
            } catch {
                // removeItem can fail halfway through a folder; count what did go.
                report.freedBytes += removedBytes(of: item, at: target)
                throw error
            }

        case .emptyContents:
            let children = try fileManager.contentsOfDirectory(at: target, includingPropertiesForKeys: nil, options: [])
            var failed = 0
            var firstError: Error?
            for child in children {
                do {
                    try fileManager.removeItem(at: child)
                } catch {
                    failed += 1
                    if firstError == nil { firstError = error }
                }
            }
            if failed == 0 {
                report.freedBytes += item.size
            } else {
                report.freedBytes += removedBytes(of: item, at: target)
                throw CleanError.partiallyEmptied(
                    failed: failed,
                    total: children.count,
                    reason: firstError?.localizedDescription ?? ""
                )
            }
        }
    }

    /// Scan-time size minus whatever is still on disk.
    private func removedBytes(of item: CleanableItem, at target: URL) -> Int64 {
        max(0, item.size - FileSizer.measure(target).size)
    }
}

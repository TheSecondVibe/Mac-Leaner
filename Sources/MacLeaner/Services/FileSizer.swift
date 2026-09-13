import Foundation

struct DiskUsage: Sendable {
    var size: Int64 = 0
    var fileCount = 0
    var newestModification: Date?
    var isDirectory = false
}

/// Measures what files actually occupy on disk.
enum FileSizer {
    private static let keys: [URLResourceKey] = [
        .isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey, .contentModificationDateKey,
    ]

    /// Allocated size of a file or folder. Sparse files (like `Docker.raw`) count
    /// what they really use, and symlinks are never followed.
    static func measure(_ url: URL) -> DiskUsage {
        let keySet = Set(keys)
        guard let top = try? url.resourceValues(forKeys: keySet.union([.isDirectoryKey])),
              top.isSymbolicLink != true else { return DiskUsage() }

        guard top.isDirectory == true else {
            return DiskUsage(size: allocated(top), fileCount: 1, newestModification: top.contentModificationDate)
        }

        var usage = DiskUsage(isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return usage }

        var visited = 0
        while let next = enumerator.nextObject() as? URL {
            visited += 1
            if visited.isMultiple(of: 4096), Task.isCancelled { break }
            guard let values = try? next.resourceValues(forKeys: keySet),
                  values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            usage.size += allocated(values)
            usage.fileCount += 1
            if let date = values.contentModificationDate, date > (usage.newestModification ?? .distantPast) {
                usage.newestModification = date
            }
        }
        return usage
    }

    private static func allocated(_ values: URLResourceValues) -> Int64 {
        Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }
}

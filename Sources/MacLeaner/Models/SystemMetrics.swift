import Foundation
import Darwin

struct SystemMetrics: Sendable, Equatable {
    var totalDisk: Int64 = 0
    /// Free space as Finder reports it (includes purgeable space macOS can reclaim).
    var availableDisk: Int64 = 0
    var totalMemory: UInt64 = 0
    var usedMemory: UInt64 = 0

    var usedDisk: Int64 { max(0, totalDisk - availableDisk) }
    var diskUsage: Double { totalDisk > 0 ? Double(usedDisk) / Double(totalDisk) : 0 }
    var memoryUsage: Double { totalMemory > 0 ? min(1, Double(usedMemory) / Double(totalMemory)) : 0 }

    static func current() -> SystemMetrics {
        var metrics = SystemMetrics()
        let home = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? home.resourceValues(forKeys: [.volumeTotalCapacityKey]) {
            metrics.totalDisk = Int64(values.volumeTotalCapacity ?? 0)
        }
        metrics.availableDisk = availableDiskSpace(at: home)
        metrics.totalMemory = ProcessInfo.processInfo.physicalMemory
        metrics.usedMemory = usedMemoryBytes() ?? 0
        return metrics
    }

    static func availableDiskSpace(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        return values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)
    }

    /// Matches Activity Monitor's "Memory Used": app memory + wired + compressed.
    private static func usedMemoryBytes() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let pageSize = UInt64(getpagesize())
        let internalPages = UInt64(stats.internal_page_count)
        let purgeablePages = UInt64(stats.purgeable_count)
        let appPages = internalPages > purgeablePages ? internalPages - purgeablePages : 0
        return (appPages + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * pageSize
    }
}

import Foundation

struct FolderUsageAccumulator {
    let root: URL
    private var totals: [String: FolderUsage] = [:]
    private(set) var limited = false

    init(root: URL) { self.root = root }

    mutating func record(file: URL, bytes: Int64) {
        guard ScanPolicy.contains(root, file) else { return }
        let relative = file.deletingLastPathComponent().path.dropFirst(root.path == "/" ? 1 : root.path.count + 1)
        let parts = relative.split(separator: "/")
        var folder = root
        // shortcut: keep eight levels and 50k folders; use post-order streaming if deeper analysis becomes necessary.
        for part in parts.prefix(8) {
            folder.appendPathComponent(String(part))
            let path = folder.path
            if totals[path] == nil && totals.count >= 50_000 { limited = true; continue }
            totals[path, default: FolderUsage(url: folder)].bytes += bytes
            totals[path, default: FolderUsage(url: folder)].fileCount += 1
        }
        if parts.count > 8 { limited = true }
    }

    var largest: [FolderUsage] {
        Array(totals.values.filter { $0.bytes >= ScanPolicy.largeFileBytes }
            .sorted { $0.bytes == $1.bytes ? $0.id < $1.id : $0.bytes > $1.bytes }.prefix(100))
    }
}

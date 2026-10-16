import Foundation

public struct DeepScanner: Sendable {
    public static let minimumFileBytes: Int64 = 10_000_000
    public let policy: ScanPolicy
    public let systemRoot: URL
    public let isRegistered: @Sendable (String) -> Bool

    public init(policy: ScanPolicy = ScanPolicy(), systemRoot: URL = URL(fileURLWithPath: "/"),
                isRegistered: @escaping @Sendable (String) -> Bool = ApplicationInventory.isRegistered) {
        self.policy = policy
        self.systemRoot = systemRoot.standardizedFileURL
        self.isRegistered = isRegistered
    }

    private func excluded(_ url: URL) -> Bool {
        let relative = url.path.dropFirst(systemRoot.path == "/" ? 1 : systemRoot.path.count + 1).lowercased()
        let parts = relative.split(separator: "/").map(String.init)
        let pseudoRoots: Set<String> = ["dev", "proc", "net", "network", "volumes", ".vol"]
        let privateNames: Set<String> = [".ssh", ".gnupg", ".aws", ".kube", "keychains", ".trash", ".trashes", ".spotlight-v100", ".fseventsd", ".documentrevisions-v100"]
        return pseudoRoots.contains(parts.first ?? "") || relative == "system/volumes" ||
            relative.hasPrefix("system/volumes/") || parts.contains(where: privateNames.contains)
    }

    public func scan(now: Date = Date(), isCancelled: @Sendable () -> Bool = { false },
                     onProgress: @Sendable (ScanProgress) -> Void = { _ in },
                     onSnapshot: @Sendable (ScanReport) -> Void = { _ in }) -> ScanReport {
        var report = Scanner(policy: policy).scan(now: now, isCancelled: isCancelled,
            onProgress: onProgress, onSnapshot: onSnapshot)
        if report.cancelled { return report }
        onProgress(ScanProgress(visitedFiles: report.visitedFiles, foundFiles: report.items.count,
            category: .appLeftovers, currentPath: "Đang lập danh mục ứng dụng .app"))
        var inventory = ApplicationInventory.scan(
            roots: ApplicationInventory.defaultRoots(home: policy.home, systemRoot: systemRoot), isCancelled: isCancelled)
        var systemItems = LargestFileResults(limit: 20_000)
        var folders = FolderUsageAccumulator(root: systemRoot)
        var scannedBytes: Int64 = 0
        var visited = report.visitedFiles
        var directories = report.visitedDirectories
        var entries = 0
        var lastSnapshot: ContinuousClock.Instant?

        func mergedItems(extra: [ScanItem] = [], limit: Int) -> (items: [ScanItem], limited: Bool) {
            var items = Dictionary(uniqueKeysWithValues: systemItems.largest.map { ($0.id, $0) })
            for item in report.items + extra { items[item.id] = item }
            let prioritized = items.values.sorted {
                if ($0.category == .appLeftovers) != ($1.category == .appLeftovers) { return $0.category == .appLeftovers }
                return $0.bytes == $1.bytes ? $0.id < $1.id : $0.bytes > $1.bytes
            }
            let kept = Array(prioritized.prefix(limit)).sorted { $0.bytes == $1.bytes ? $0.id < $1.id : $0.bytes > $1.bytes }
            return (kept, items.count > limit)
        }
        func publish() {
            var snapshot = report
            snapshot.items = mergedItems(limit: 500).items
            snapshot.visitedFiles = visited
            snapshot.visitedDirectories = directories
            snapshot.scannedBytes = scannedBytes
            snapshot.folderUsages = folders.largest
            snapshot.folderSummaryLimited = folders.limited
            snapshot.applicationCount = inventory.identifiers.count
            onSnapshot(snapshot)
        }
        func warn(_ url: URL, _ error: Error) {
            report.readErrors += 1
            if report.warnings.count < 100 { report.warnings.append(ScanWarning(path: url.path, messageText: .init(error: error))) }
        }
        let status = FileTreeWalker.walk(at: systemRoot, includeHidden: true, includePackages: true, isCancelled: isCancelled, visit: { url, metadata in
            guard !excluded(url) else { return false }
            entries += 1
            if metadata.isDirectory {
                directories += 1
                if url.pathExtension.lowercased() == "app" { inventory.recordApplication(at: url) }
            }
            if metadata.isRegular {
                visited += 1
                scannedBytes += metadata.snapshot.size
                folders.record(file: url, bytes: metadata.snapshot.size)
                if metadata.snapshot.size >= Self.minimumFileBytes {
                    systemItems.insert(ScanItem(url: url, category: .systemFiles, snapshot: metadata.snapshot, isReadOnly: true))
                }
            }
            if entries % 200 == 0 {
                let instant = ContinuousClock.now
                if (lastSnapshot?.duration(to: instant) ?? .seconds(1)) >= .milliseconds(500) {
                    onProgress(ScanProgress(visitedFiles: visited, foundFiles: report.items.count + systemItems.count,
                        category: .systemFiles, currentPath: url.deletingLastPathComponent().path))
                    publish()
                    lastSnapshot = instant
                }
            }
            return true
        }, onError: warn)
        report.visitedFiles += status.files
        report.visitedDirectories += status.directories
        report.scannedBytes = scannedBytes
        report.folderUsages = folders.largest
        report.folderSummaryLimited = folders.limited
        report.limited = report.limited || systemItems.limited
        report.cancelled = status.cancelled || isCancelled()
        report.applicationCount = inventory.identifiers.count
        report.warnings = Array((report.warnings + inventory.warnings).prefix(100))
        report.readErrors += inventory.warnings.count
        publish()
        var leftovers = ScanReport()
        if !report.cancelled {
            onProgress(ScanProgress(visitedFiles: report.visitedFiles, foundFiles: report.items.count + systemItems.count,
                category: .appLeftovers, currentPath: L10n.text("Đang đối chiếu dữ liệu ứng dụng còn sót")))
            leftovers = LeftoverScanner(policy: policy, inventory: inventory, systemRoot: systemRoot, isRegistered: isRegistered).scan(isCancelled: isCancelled)
        }
        report.cancelled = report.cancelled || leftovers.cancelled
        report.limited = report.limited || leftovers.limited
        report.warnings = Array((report.warnings + leftovers.warnings).prefix(100))
        report.readErrors += leftovers.warnings.count
        let merged = mergedItems(extra: leftovers.items, limit: 20_000)
        report.limited = report.limited || merged.limited
        report.items = merged.items
        report.deepScanCompleted = !report.cancelled
        return report
    }
}

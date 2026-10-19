import Foundation

public struct Scanner: Sendable {
    public let policy: ScanPolicy
    public init(policy: ScanPolicy = ScanPolicy()) { self.policy = policy }

    public func scan(
        now: Date = Date(),
        isCancelled: @Sendable () -> Bool = { false },
        onProgress: @Sendable (ScanProgress) -> Void = { _ in },
        onSnapshot: @Sendable (ScanReport) -> Void = { _ in }
    ) -> ScanReport {
        let fm = FileManager()
        var report = ScanReport()
        var seen = Set<String>()
        var lastSnapshot: ContinuousClock.Instant?
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .isAliasFileKey, .isUbiquitousItemKey]
        func warn(_ url: URL, _ error: Error) {
            report.readErrors += 1
            if report.warnings.count < 100 {
                report.warnings.append(ScanWarning(path: url.path, messageText: .init(error: error)))
            }
        }
        for root in policy.roots {
            if isCancelled() { report.cancelled = true; break }
            do {
                try policy.validateRoot(root)
            } catch {
                let nsError = error as NSError
                if nsError.domain != NSPOSIXErrorDomain || nsError.code != Int(ENOENT) { warn(root.url, error) }
                continue
            }
            guard let enumerator = fm.enumerator(
                at: root.url, includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { url, error in warn(url, error); return true }
            ) else {
                warn(root.url, CocoaError(.fileReadUnknown))
                continue
            }
            while let url = enumerator.nextObject() as? URL {
                if isCancelled() { report.cancelled = true; break }
                do {
                    let values = try url.resourceValues(forKeys: Set(keys))
                    let metadata = try FileMetadata.read(url)
                    if metadata.isSymbolicLink || metadata.isDataless || values.isPackage == true ||
                        values.isAliasFile == true || values.isUbiquitousItem == true ||
                        ScanPolicy.packageExtensions.contains(url.pathExtension.lowercased()) {
                        enumerator.skipDescendants()
                        continue
                    }
                    if metadata.isDirectory { report.visitedDirectories += 1; continue }
                    guard metadata.isRegular else { continue }
                    report.visitedFiles += 1
                    report.scannedBytes += metadata.snapshot.size
                    if seen.insert(url.path).inserted,
                       let item = try policy.candidate(at: url, now: now, checkAncestors: false) {
                        report.items.append(item)
                    }
                    if report.visitedFiles % 200 == 0 {
                        let instant = ContinuousClock.now
                        if (lastSnapshot?.duration(to: instant) ?? .seconds(1)) >= .milliseconds(500) {
                            onProgress(ScanProgress(visitedFiles: report.visitedFiles, foundFiles: report.items.count, category: root.category, currentPath: url.deletingLastPathComponent().path))
                            onSnapshot(report.preview)
                            lastSnapshot = instant
                        }
                    }
                } catch { warn(url, error) }
            }
            onProgress(ScanProgress(visitedFiles: report.visitedFiles, foundFiles: report.items.count, category: root.category))
            if report.cancelled { break }
        }
        report.items.sort { $0.bytes == $1.bytes ? $0.id < $1.id : $0.bytes > $1.bytes }
        onSnapshot(report.preview)
        return report
    }
}

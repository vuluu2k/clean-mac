import Foundation

public struct LeftoverScanner: Sendable {
    public let policy: ScanPolicy
    public let inventory: ApplicationInventory
    public let systemRoot: URL
    public let isRegistered: @Sendable (String) -> Bool

    public init(policy: ScanPolicy, inventory: ApplicationInventory,
                systemRoot: URL = URL(fileURLWithPath: "/"),
                isRegistered: @escaping @Sendable (String) -> Bool = ApplicationInventory.isRegistered) {
        self.policy = policy
        self.inventory = inventory
        self.systemRoot = systemRoot.standardizedFileURL
        self.isRegistered = isRegistered
    }

    private var locations: [ApplicationDataLocation] {
        ApplicationDataLocation.defaults(home: policy.home, systemRoot: systemRoot)
    }

    func candidate(at url: URL, revalidate: Bool = true) throws -> ScanItem? {
        guard let location = locations.first(where: { ScanPolicy.contains($0.root, url) }),
              let identifier = location.owner(of: url) else { return nil }
        if revalidate {
            guard !inventory.mayOwn(identifier), !isRegistered(identifier) else { return nil }
            try policy.validatePath(url, beneath: location.userOwned ? policy.home : systemRoot)
        }
        let metadata = try FileMetadata.read(url)
        guard metadata.isRegular, metadata.linkCount == 1, !metadata.isDataless, metadata.snapshot.size > 0 else { return nil }
        let readOnly = !location.cleanable || !inventory.complete || ScanPolicy.isProtectedFile(url)
        let restriction: LocalizedText = !inventory.complete ? .init("Danh mục ứng dụng chưa đầy đủ: chỉ xem.") : readOnly ? .init("Vị trí dùng chung, container, dịch vụ hoặc database: chỉ xem.") : .init("Có thể chứa dữ liệu offline và thiết lập. Chỉ chọn khi chắc chắn không cần.")
        let evidence: [LocalizedText] = [.init("Bundle ID: \(identifier). Không thấy .app tương ứng trong danh mục \(inventory.identifiers.count) ID và LaunchServices. Không chứng minh app đã gỡ: có thể là app portable, plugin hoặc CLI."), restriction]
        return ScanItem(url: url, category: .appLeftovers, snapshot: metadata.snapshot,
            applicationID: identifier, evidence: evidence, isReadOnly: readOnly)
    }

    public func scan(isCancelled: @Sendable () -> Bool = { false }) -> ScanReport {
        var report = ScanReport()
        let fm = FileManager()
        func warn(_ url: URL, _ error: Error) {
            if report.warnings.count < 100 { report.warnings.append(ScanWarning(path: url.path, messageText: .init(error: error))) }
        }
        func append(_ url: URL) {
            do {
                if let item = try candidate(at: url, revalidate: false) {
                    if report.items.count < 20_000 { report.items.append(item) } else { report.limited = true }
                }
            } catch { warn(url, error) }
        }
        for location in locations {
            if isCancelled() { report.cancelled = true; break }
            do {
                try policy.validatePath(location.root, beneath: location.userOwned ? policy.home : systemRoot)
                // Preserve the validated root spelling: Cocoa URL listings can rewrite /var to /private/var.
                let names = try fm.contentsOfDirectory(atPath: location.root.path)
                for name in names {
                    let child = location.root.appendingPathComponent(name)
                    if isCancelled() { report.cancelled = true; break }
                    guard let identifier = location.owner(of: child), !inventory.mayOwn(identifier), !isRegistered(identifier) else { continue }
                    let metadata = try FileMetadata.read(child)
                    guard !metadata.isSymbolicLink, !metadata.isDataless else { continue }
                    if location.plist { append(child); continue }
                    guard metadata.isDirectory else { continue }
                    try policy.validatePath(child, beneath: location.userOwned ? policy.home : systemRoot)
                    let status = FileTreeWalker.walk(at: child, isCancelled: isCancelled, visit: { url, info in
                        if info.isRegular { append(url) }
                        return true
                    }, onError: warn)
                    report.visitedFiles += status.files
                    report.cancelled = report.cancelled || status.cancelled
                }
            } catch {
                let error = error as NSError
                if error.domain != NSPOSIXErrorDomain || error.code != Int(ENOENT) { warn(location.root, error) }
            }
        }
        return report
    }
}

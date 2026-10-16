import Foundation

public struct CleanupService: Sendable {
    public let policy: ScanPolicy
    public let systemRoot: URL
    public let isRegistered: @Sendable (String) -> Bool

    public init(policy: ScanPolicy = ScanPolicy(), systemRoot: URL = URL(fileURLWithPath: "/"),
                isRegistered: @escaping @Sendable (String) -> Bool = ApplicationInventory.isRegistered) {
        self.policy = policy
        self.systemRoot = systemRoot.standardizedFileURL
        self.isRegistered = isRegistered
    }

    public func moveToTrash(
        _ items: [ScanItem],
        now: Date = Date(),
        trash: (URL) throws -> Void = { try FileManager().trashItem(at: $0, resultingItemURL: nil) }
    ) -> CleanupReport {
        var report = CleanupReport()
        var seen = Set<String>()
        guard items.count <= 20_000 else {
            report.failures = items.prefix(1).map { CleanupFailure(path: $0.id, messageText: SafetyError.tooManyFiles.localizedText) }
            return report
        }
        var leftovers: LeftoverScanner?
        if items.contains(where: { $0.category == .appLeftovers && $0.canTrash }) {
            let inventory = ApplicationInventory.scan(roots: ApplicationInventory.defaultRoots(home: policy.home, systemRoot: systemRoot))
            leftovers = LeftoverScanner(policy: policy, inventory: inventory, systemRoot: systemRoot, isRegistered: isRegistered)
        }
        for item in items where seen.insert(item.id).inserted {
            do {
                guard item.canTrash else { throw SafetyError.readOnly }
                let candidate: ScanItem?
                if item.category == .appLeftovers {
                    candidate = try leftovers?.candidate(at: item.url)
                } else {
                    candidate = try policy.candidate(at: item.url, now: now)
                }
                guard let current = candidate, current.canTrash, current.category == item.category,
                      current.applicationID == item.applicationID else { throw SafetyError.notEligible }
                guard current.snapshot == item.snapshot else { throw SafetyError.changedFile }
                try trash(item.url)
                report.moved.append(item)
            } catch {
                report.failures.append(CleanupFailure(path: item.id, messageText: .init(error: error)))
            }
        }
        return report
    }
}

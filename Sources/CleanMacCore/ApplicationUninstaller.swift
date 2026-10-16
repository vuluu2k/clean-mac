import AppKit
import Foundation

public struct ApplicationUninstaller: Sendable {
    public let policy: ScanPolicy
    public let systemRoot: URL
    public let isRunning: @Sendable (InstalledApplication) -> Bool
    public let registeredURL: @Sendable (String) -> URL?

    public init(policy: ScanPolicy = ScanPolicy(), systemRoot: URL = URL(fileURLWithPath: "/"),
                isRunning: @escaping @Sendable (InstalledApplication) -> Bool = ApplicationUninstaller.running,
                registeredURL: @escaping @Sendable (String) -> URL? = ApplicationUninstaller.registration) {
        self.policy = policy
        self.systemRoot = systemRoot.standardizedFileURL
        self.isRunning = isRunning
        self.registeredURL = registeredURL
    }

    public static func running(_ app: InstalledApplication) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            !$0.isTerminated && ($0.bundleIdentifier?.lowercased() == app.identifier.lowercased() || $0.bundleURL?.standardizedFileURL.path == app.id)
        }
    }

    public static func registration(_ identifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
    }

    public func catalog(isCancelled: @Sendable () -> Bool = { false }) -> ApplicationInventory {
        ApplicationInventory.scan(roots: ApplicationInventory.defaultRoots(home: policy.home, systemRoot: systemRoot), isCancelled: isCancelled)
    }

    public func protectionReason(for app: InstalledApplication) -> String? { protectionText(for: app)?.localized() }

    public func protectionText(for app: InstalledApplication) -> LocalizedText? {
        let identifier = app.identifier.lowercased()
        if identifier == "com.apple" || identifier.hasPrefix("com.apple.") { return .init("Ứng dụng Apple: giữ lại trong chế độ an toàn.") }
        if identifier == "app.cleanmac.local" || app.id == Bundle.main.bundleURL.standardizedFileURL.path { return .init("Không tự gỡ clean-mac đang sử dụng.") }
        guard app.url.pathExtension.lowercased() == "app",
              ScanPolicy.contains(systemRoot.appendingPathComponent("Applications"), app.url) ||
              ScanPolicy.contains(policy.home.appendingPathComponent("Applications"), app.url) else {
            return .init("Ngoài /Applications hoặc ~/Applications; chỉ xem.")
        }
        if isRunning(app) { return .init("Ứng dụng đang chạy. Hãy tự thoát ứng dụng và phân tích lại trước khi gỡ.") }
        return nil
    }

    private func validate(_ app: InstalledApplication) throws -> InstalledApplication {
        guard protectionText(for: app) == nil else { throw SafetyError.readOnly }
        let current = try InstalledApplication.read(at: app.url)
        guard current.identifier == app.identifier, current.snapshot == app.snapshot else { throw SafetyError.changedFile }
        guard protectionText(for: current) == nil else { throw SafetyError.readOnly }
        let base = ScanPolicy.contains(policy.home.appendingPathComponent("Applications"), app.url) ? policy.home : systemRoot
        try policy.validatePath(app.url.deletingLastPathComponent(), beneath: base)
        let values = try app.url.resourceValues(forKeys: [.isAliasFileKey, .isUbiquitousItemKey])
        guard !app.url.lastPathComponent.hasPrefix("."), values.isAliasFile != true, values.isUbiquitousItem != true else { throw SafetyError.unsafePath }
        return current
    }

    private func dataProtectionReason(for app: InstalledApplication, inventory: ApplicationInventory) -> LocalizedText? {
        if !inventory.complete { return .init("Danh mục ứng dụng chưa đầy đủ: giữ lại dữ liệu liên quan.") }
        if inventory.mayOwn(app.identifier, excluding: app.url) { return .init("Còn app cùng ID/nhà phát hành: dữ liệu có thể dùng chung, giữ lại.") }
        if let registered = registeredURL(app.identifier) {
            do {
                let metadata = try FileMetadata.read(registered)
                if metadata.snapshot.device != app.snapshot.device || metadata.snapshot.inode != app.snapshot.inode {
                    return .init("LaunchServices còn nhận diện bản app khác: giữ lại dữ liệu.")
                }
            } catch {
                let error = error as NSError
                if error.domain != NSPOSIXErrorDomain || error.code != Int(ENOENT) { return .init("Không xác minh được bản app đã đăng ký: giữ lại dữ liệu.") }
            }
        }
        return nil
    }

    private func relatedFile(at url: URL, app: InstalledApplication, lockReason: LocalizedText?, now: Date) throws -> RelatedApplicationFile? {
        guard let location = ApplicationDataLocation.defaults(home: policy.home, systemRoot: systemRoot).first(where: {
            $0.owner(of: url)?.lowercased() == app.identifier.lowercased()
        }) else { return nil }
        try policy.validatePath(url, beneath: location.userOwned ? policy.home : systemRoot)
        let metadata = try FileMetadata.read(url)
        guard metadata.isRegular, metadata.linkCount == 1, !metadata.isDataless, metadata.snapshot.size > 0 else { return nil }
        let restriction: LocalizedText? = lockReason ?? (!location.cleanable || ScanPolicy.isProtectedFile(url) ? .init("Container, database, dịch vụ hoặc dữ liệu dùng chung: không cho dọn.") : nil)
        let oldCache = ["Caches", "Logs"].contains(location.root.lastPathComponent) && now.timeIntervalSince(metadata.snapshot.modifiedAt) >= 14 * 86_400
        let level: CleanupRecommendation = restriction != nil ? .keep : oldCache ? .recommended : .review
        let reason: LocalizedText = restriction ?? (oldCache ? .init("Cache/log khớp bundle ID, cũ ít nhất 14 ngày; có thể phải tạo lại hoặc mất dữ liệu offline.") : .init("Khớp bundle ID nhưng có thể chứa thiết lập/dữ liệu offline. Chỉ chọn nếu muốn bỏ dữ liệu này."))
        return RelatedApplicationFile(url: url, snapshot: metadata.snapshot, recommendation: level, reasonText: reason)
    }

    private struct RelatedData {
        var files: [RelatedApplicationFile] = []
        var warnings: [ScanWarning] = []
        var limited = false
        var cancelled = false
    }

    private func relatedFiles(for app: InstalledApplication, lockReason: LocalizedText?, now: Date,
                              isCancelled: @Sendable () -> Bool) -> RelatedData {
        var result = RelatedData()
        var seen = Set<String>()
        var visitedEntries = 0
        func warn(_ url: URL, _ error: Error) {
            if result.warnings.count < 100 { result.warnings.append(ScanWarning(path: url.path, messageText: .init(error: error))) }
        }
        func append(_ url: URL) {
            do {
                if let file = try relatedFile(at: url, app: app, lockReason: lockReason, now: now), seen.insert(file.id).inserted {
                    if result.files.count < 20_000 { result.files.append(file) } else { result.limited = true }
                }
            } catch { warn(url, error) }
        }
        for location in ApplicationDataLocation.defaults(home: policy.home, systemRoot: systemRoot) {
            if isCancelled() { result.cancelled = true; break }
            if visitedEntries >= 50_000 || result.limited { result.limited = true; break }
            do {
                try policy.validatePath(location.root, beneath: location.userOwned ? policy.home : systemRoot)
                for name in try FileManager().contentsOfDirectory(atPath: location.root.path) {
                    if isCancelled() { result.cancelled = true; break }
                    let child = location.root.appendingPathComponent(name)
                    guard location.owner(of: child)?.lowercased() == app.identifier.lowercased() else { continue }
                    let metadata = try FileMetadata.read(child)
                    guard !metadata.isSymbolicLink, !metadata.isDataless else { continue }
                    try policy.validatePath(child, beneath: location.userOwned ? policy.home : systemRoot)
                    if metadata.isRegular { append(child) }
                    else if metadata.isDirectory {
                        let status = FileTreeWalker.walk(at: child, maximumEntries: 50_000 - visitedEntries, isCancelled: isCancelled, visit: { url, info in
                            if info.isRegular { append(url) }
                            return !result.limited
                        }, onError: warn)
                        visitedEntries += status.entries
                        result.limited = result.limited || status.limited
                        result.cancelled = result.cancelled || status.cancelled
                    }
                }
            } catch {
                let error = error as NSError
                if error.domain != NSPOSIXErrorDomain || error.code != Int(ENOENT) { warn(location.root, error) }
            }
        }
        result.files.sort { $0.bytes == $1.bytes ? $0.id < $1.id : $0.bytes > $1.bytes }
        return result
    }

    public func uninstall(_ plan: ApplicationRemovalPlan, selectedDataIDs: Set<String>,
                          isCancelled: @Sendable () -> Bool = { false },
                          trash: (URL) throws -> Void = { try FileManager().trashItem(at: $0, resultingItemURL: nil) }) -> ApplicationRemovalReport {
        var report = ApplicationRemovalReport()
        var checkingPath = plan.application.id
        let selected = plan.files.filter { selectedDataIDs.contains($0.id) }
        do {
            guard plan.canRemoveApplication, let expected = plan.bundleSnapshot else { throw SafetyError.readOnly }
            guard plan.files.count <= 20_000, Set(plan.files.map(\.id)).count == plan.files.count,
                  selectedDataIDs.isSubset(of: Set(plan.files.filter(\.canTrash).map(\.id))) else { throw SafetyError.notEligible }
            if isCancelled() { throw SafetyError.cancelled }
            let app = try validate(plan.application)
            guard try ApplicationBundleSnapshot.capture(app.url, isCancelled: isCancelled) == expected else { throw SafetyError.changedFile }
            let inventory = catalog(isCancelled: isCancelled)
            let lock = dataProtectionReason(for: app, inventory: inventory)
            for file in selected {
                checkingPath = file.id
                guard let current = try relatedFile(at: file.url, app: app, lockReason: lock, now: Date()),
                      current.canTrash, current.snapshot == file.snapshot else { throw SafetyError.changedFile }
            }
            checkingPath = app.id
            if isCancelled() { throw SafetyError.cancelled }
            _ = try validate(app)
            try trash(app.url)
            report.applicationMoved = true
            report.applicationBytes = expected.bytes
        } catch {
            report.failures.append(CleanupFailure(path: checkingPath, messageText: .init(error: error)))
            return report
        }
        let app = plan.application
        let inventory = catalog(isCancelled: isCancelled)
        for file in selected {
            do {
                if isCancelled() { throw SafetyError.cancelled }
                guard !isRunning(app) else { throw SafetyError.readOnly }
                do {
                    _ = try FileMetadata.read(app.url)
                    throw SafetyError.changedFile
                } catch {
                    let error = error as NSError
                    guard error.domain == NSPOSIXErrorDomain, error.code == Int(ENOENT) else { throw error }
                }
                guard let current = try relatedFile(at: file.url, app: app,
                    lockReason: dataProtectionReason(for: app, inventory: inventory), now: Date()),
                    current.canTrash, current.snapshot == file.snapshot else { throw SafetyError.changedFile }
                try trash(file.url)
                report.movedFiles.append(file)
            } catch { report.failures.append(CleanupFailure(path: file.id, messageText: .init(error: error))) }
        }
        return report
    }

    public func review(_ app: InstalledApplication, now: Date = Date(),
                       isCancelled: @Sendable () -> Bool = { false }) -> ApplicationRemovalPlan {
        do {
            if let reason = protectionText(for: app) {
                return ApplicationRemovalPlan(application: app, bundleSnapshot: nil, files: [], warnings: [], protectionText: reason, limited: false, cancelled: false)
            }
            let current = try validate(app)
            let snapshot = try ApplicationBundleSnapshot.capture(current.url, isCancelled: isCancelled)
            let inventory = catalog(isCancelled: isCancelled)
            let data = relatedFiles(for: current, lockReason: dataProtectionReason(for: current, inventory: inventory), now: now, isCancelled: isCancelled)
            return ApplicationRemovalPlan(application: current, bundleSnapshot: snapshot, files: data.files, warnings: Array((inventory.warnings + data.warnings).prefix(100)),
                protectionText: nil, limited: data.limited, cancelled: data.cancelled || isCancelled())
        } catch {
            return ApplicationRemovalPlan(application: app, bundleSnapshot: nil, files: [], warnings: [],
                protectionText: .init(error: error), limited: false, cancelled: isCancelled())
        }
    }
}

import AppKit
import CleanMacCore
import SwiftUI

struct CleanupConfirmation: Identifiable {
    let id = UUID()
    let items: [ScanItem]
    var bytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
}

struct ApplicationRemovalConfirmation: Identifiable {
    let id = UUID()
    let plan: ApplicationRemovalPlan
    let files: [RelatedApplicationFile]
    var selectedDataIDs: Set<String> { Set(files.map(\.id)) }
    var bytes: Int64 { plan.applicationBytes + files.reduce(0) { $0 + $1.bytes } }
}

@MainActor
final class AppModel: ObservableObject {
    enum Phase { case idle, scanning, cleaning, scanningApplications, reviewingApplication, uninstalling }
    enum Page { case cleaner, applications }
    enum ApplicationFilter { case all, removable, keep }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var report = ScanReport()
    @Published private(set) var cleanupReport: CleanupReport?
    @Published private(set) var disk: DiskSpace?
    @Published private(set) var diskError: String?
    @Published private(set) var progress: ScanProgress?
    @Published private(set) var hasScanned = false
    @Published private(set) var reviewFolders: [URL] = []
    @Published private(set) var scanMode: ScanMode = .quick
    @Published private(set) var language = AppLanguage.current
    @Published var page: Page = .cleaner
    @Published private(set) var applicationCatalog: ApplicationInventory?
    @Published private(set) var applicationProtections: [String: LocalizedText] = [:]
    @Published var applicationFilter: ApplicationFilter = .all
    @Published private(set) var applicationRemovalReport: ApplicationRemovalReport?
    @Published private(set) var applicationStatus = LocalizedText("")
    @Published var applicationQuery = ""
    @Published var applicationPlan: ApplicationRemovalPlan?
    @Published var applicationConfirmation: ApplicationRemovalConfirmation?
    @Published var selectedRelatedIDs = Set<String>()
    @Published var recommendationFilter: CleanupRecommendation?
    @Published var selectedIDs = Set<String>()
    @Published var category: CleanupCategory?
    @Published var query = ""
    @Published var confirmation: CleanupConfirmation?
    @Published var inspectedItem: ScanItem?
    @Published var alertMessage: String?
    @Published var showIssues = false
    private var worker: Task<Void, Never>?
    private var activeScanID: UUID?
    let home: URL
    let systemRoot: URL
    private let isRegistered: @Sendable (String) -> Bool
    private let isApplicationRunning: @Sendable (InstalledApplication) -> Bool
    private let registeredApplicationURL: @Sendable (String) -> URL?
    private let trashOperation: @Sendable (URL) throws -> Void

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
         systemRoot: URL = URL(fileURLWithPath: "/"),
         isRegistered: @escaping @Sendable (String) -> Bool = ApplicationInventory.isRegistered,
         isApplicationRunning: @escaping @Sendable (InstalledApplication) -> Bool = ApplicationUninstaller.running,
         registeredApplicationURL: @escaping @Sendable (String) -> URL? = ApplicationUninstaller.registration,
         trashOperation: @escaping @Sendable (URL) throws -> Void = { try FileManager().trashItem(at: $0, resultingItemURL: nil) }) {
        self.home = home.resolvingSymlinksInPath().standardizedFileURL
        self.systemRoot = systemRoot.standardizedFileURL
        self.isRegistered = isRegistered
        self.isApplicationRunning = isApplicationRunning
        self.registeredApplicationURL = registeredApplicationURL
        self.trashOperation = trashOperation
    }

    var busy: Bool { phase != .idle }
    var hasOpenReview: Bool { confirmation != nil || applicationPlan != nil || applicationConfirmation != nil }
    var applicationUninstaller: ApplicationUninstaller {
        ApplicationUninstaller(policy: policy, systemRoot: systemRoot, isRunning: isApplicationRunning, registeredURL: registeredApplicationURL)
    }
    var filteredApplications: [InstalledApplication] {
        (applicationCatalog?.applications ?? []).filter { app in
            let removable = applicationProtections[app.id] == nil
            let matches = applicationFilter == .all || (applicationFilter == .removable && removable) || (applicationFilter == .keep && !removable)
            return matches && (applicationQuery.isEmpty || app.name.localizedCaseInsensitiveContains(applicationQuery) ||
                app.identifier.localizedCaseInsensitiveContains(applicationQuery) || app.id.localizedCaseInsensitiveContains(applicationQuery))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var hasVisibleResults: Bool { hasScanned || report.visitedFiles > 0 || !report.items.isEmpty || !report.folderUsages.isEmpty }
    var policy: ScanPolicy { ScanPolicy(home: home, reviewFolders: reviewFolders) }
    var selectedItems: [ScanItem] { report.items.filter { $0.canTrash && selectedIDs.contains($0.id) } }
    var selectedBytes: Int64 { selectedItems.reduce(0) { $0 + $1.bytes } }
    var issueCount: Int { report.warnings.count + (cleanupReport?.failures.count ?? 0) }
    var filteredItems: [ScanItem] {
        report.items.filter {
            (category == nil || $0.category == category) &&
            (recommendationFilter == nil || $0.recommendation == recommendationFilter) &&
            (query.isEmpty || $0.url.path.localizedCaseInsensitiveContains(query))
        }
    }

    func refreshDisk() async {
        let home = policy.home
        let result = await Task.detached(priority: .utility) { Result { try DiskSpace.read(at: home) } }.value
        switch result {
        case .success(let space): disk = space; diskError = nil
        case .failure(let error): disk = nil; diskError = error.localizedDescription
        }
    }

    func scan() {
        guard !busy, !hasOpenReview else { return }
        phase = .scanning
        page = .cleaner
        recommendationFilter = nil
        selectedIDs.removeAll()
        report = ScanReport()
        hasScanned = false
        progress = nil
        cleanupReport = nil
        let policy = policy
        let mode = scanMode
        let scanID = UUID()
        activeScanID = scanID
        worker = Task.detached(priority: .utility) { [self] in
            let update: @Sendable (ScanProgress) -> Void = { progress in
                Task { @MainActor in
                    guard self.phase == .scanning, self.activeScanID == scanID else { return }
                    self.progress = progress
                }
            }
            let preview: @Sendable (ScanReport) -> Void = { snapshot in
                Task { @MainActor in
                    guard self.phase == .scanning, self.activeScanID == scanID else { return }
                    self.report = snapshot
                }
            }
            let report: ScanReport
            if mode == .deep {
                report = DeepScanner(policy: policy, systemRoot: systemRoot, isRegistered: isRegistered)
                    .scan(isCancelled: { Task.isCancelled }, onProgress: update, onSnapshot: preview)
            } else {
                report = Scanner(policy: policy).scan(isCancelled: { Task.isCancelled }, onProgress: update, onSnapshot: preview)
            }
            await self.finishScan(report)
        }
    }

    private func finishScan(_ result: ScanReport) async {
        report = result
        hasScanned = true
        phase = .idle
        progress = nil
        activeScanID = nil
        worker = nil
        await refreshDisk()
    }

    func setScanMode(_ mode: ScanMode) {
        guard !busy, !hasOpenReview, scanMode != mode else { return }
        scanMode = mode
        category = nil
        invalidateScan()
    }

    func setLanguage(_ language: AppLanguage) {
        guard !busy, !hasOpenReview else { return }
        language.save()
        self.language = language
    }

    func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"),
              NSWorkspace.shared.open(url) else {
            alertMessage = L10n.text("Mở System Settings → Privacy & Security → Full Disk Access để cấp quyền cho clean-mac.")
            return
        }
    }

    func cancelScan() {
        guard phase == .scanning || phase == .scanningApplications || phase == .reviewingApplication else { return }
        worker?.cancel()
    }

    func selectVisible() {
        guard !busy, !hasOpenReview else { return }
        selectedIDs.formUnion(filteredItems.filter(\.canTrash).map(\.id))
    }

    func prepareCleanup() {
        guard !busy, !hasOpenReview, !selectedItems.isEmpty else { return }
        confirmation = CleanupConfirmation(items: selectedItems)
    }

    func clean(_ captured: CleanupConfirmation) {
        guard !busy, applicationPlan == nil, applicationConfirmation == nil,
              confirmation?.id == captured.id, !captured.items.isEmpty else { return }
        confirmation = nil
        phase = .cleaning
        let policy = policy
        let systemRoot = systemRoot
        let lookup = isRegistered
        let trash = trashOperation
        worker = Task.detached(priority: .utility) { [weak self] in
            let result = CleanupService(policy: policy, systemRoot: systemRoot, isRegistered: lookup).moveToTrash(captured.items, trash: trash)
            if let self { await self.finishCleanup(result) }
        }
    }

    private func finishCleanup(_ result: CleanupReport) async {
        let moved = Set(result.moved.map(\.id))
        report.items.removeAll { moved.contains($0.id) }
        selectedIDs.removeAll()
        cleanupReport = result
        phase = .idle
        worker = nil
        await refreshDisk()
    }

    func chooseFolders() {
        guard !busy, !hasOpenReview else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = policy.home
        panel.prompt = L10n.text("Thêm thư mục")
        panel.message = L10n.text("Chọn thư mục bên trong Home để tìm tệp từ 100 MB. Không quét Library, package hoặc liên kết.")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            do {
                try policy.validateReviewFolder(url)
                if !reviewFolders.contains(url.standardizedFileURL) { reviewFolders.append(url.standardizedFileURL) }
            } catch { alertMessage = "\(url.path)\n\(error.localizedDescription)" }
        }
        invalidateScan()
    }

    func removeFolder(_ url: URL) {
        guard !busy, !hasOpenReview else { return }
        reviewFolders.removeAll { $0 == url }
        invalidateScan()
    }

    func scanApplications() {
        guard !busy, !hasOpenReview else { return }
        phase = .scanningApplications
        page = .applications
        applicationStatus = .init("Đang đọc danh mục ứng dụng…")
        applicationRemovalReport = nil
        let service = applicationUninstaller
        worker = Task.detached(priority: .utility) { [self] in
            let result = service.catalog(isCancelled: { Task.isCancelled })
            let protections = Dictionary(uniqueKeysWithValues: result.applications.compactMap { app in
                service.protectionText(for: app).map { (app.id, $0) }
            })
            await self.finishApplicationCatalog(result, protections: protections)
        }
    }

    private func finishApplicationCatalog(_ result: ApplicationInventory, protections: [String: LocalizedText]) {
        applicationCatalog = result
        applicationProtections = protections
        applicationStatus = result.complete ? .init("\(result.applications.count) ứng dụng · Đã đọc danh mục") : .init("\(result.applications.count) ứng dụng · Danh mục chưa đầy đủ, xem cảnh báo")
        phase = .idle
        worker = nil
    }

    func reviewApplication(_ app: InstalledApplication) {
        guard !busy, !hasOpenReview else { return }
        phase = .reviewingApplication
        selectedRelatedIDs.removeAll()
        applicationRemovalReport = nil
        applicationStatus = .init("Đang phân tích \(app.name) và dữ liệu khớp bundle ID…")
        let service = applicationUninstaller
        worker = Task.detached(priority: .utility) { [self] in
            let result = service.review(app, isCancelled: { Task.isCancelled })
            await self.finishApplicationReview(result)
        }
    }

    private func finishApplicationReview(_ plan: ApplicationRemovalPlan) {
        applicationPlan = plan.cancelled ? nil : plan
        if !plan.cancelled { applicationProtections[plan.application.id] = plan.protectionText }
        applicationStatus = plan.cancelled ? .init("Đã dừng phân tích ứng dụng.") : .init("Đã phân tích \(plan.application.name). Chưa chọn dữ liệu nào.")
        phase = .idle
        worker = nil
    }

    func selectRecommendedApplicationFiles() {
        guard !busy, applicationConfirmation == nil, let plan = applicationPlan, plan.canRemoveApplication else { return }
        selectedRelatedIDs.formUnion(plan.files.filter { $0.canTrash && $0.recommendation == .recommended }.map(\.id))
    }

    func prepareApplicationRemoval() {
        guard !busy, confirmation == nil, applicationConfirmation == nil,
              let plan = applicationPlan, plan.canRemoveApplication else { return }
        applicationConfirmation = ApplicationRemovalConfirmation(plan: plan,
            files: plan.files.filter { $0.canTrash && selectedRelatedIDs.contains($0.id) })
    }

    func uninstallApplication(_ captured: ApplicationRemovalConfirmation) {
        guard !busy, confirmation == nil, applicationConfirmation?.id == captured.id,
              applicationPlan?.id == captured.plan.id else { return }
        applicationConfirmation = nil
        phase = .uninstalling
        applicationStatus = .init("Đang kiểm tra lại và chuyển ứng dụng vào Trash…")
        let service = applicationUninstaller
        let trash = trashOperation
        worker = Task.detached(priority: .utility) { [self] in
            let result = service.uninstall(captured.plan, selectedDataIDs: captured.selectedDataIDs, isCancelled: { Task.isCancelled }, trash: trash)
            await self.finishApplicationRemoval(result, application: captured.plan.application)
        }
    }

    private func finishApplicationRemoval(_ result: ApplicationRemovalReport, application: InstalledApplication) async {
        applicationRemovalReport = result
        applicationPlan = nil
        selectedRelatedIDs.removeAll()
        applicationStatus = result.applicationMoved ? .init("Đã chuyển \(application.name) vào Trash; chưa giải phóng dung lượng.") : .init("Chưa gỡ \(application.name). Xem lý do bên dưới.")
        if result.applicationMoved { applicationCatalog = nil; applicationProtections.removeAll(); invalidateScan() }
        phase = .idle
        worker = nil
        await refreshDisk()
    }

    private func invalidateScan() {
        recommendationFilter = nil
        report = ScanReport()
        selectedIDs.removeAll()
        hasScanned = false
        cleanupReport = nil
    }
}

func bytesText(_ bytes: Int64) -> String {
    bytes == 0 ? "0 B" : ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

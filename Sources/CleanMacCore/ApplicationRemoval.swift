import Foundation

public enum CleanupRecommendation: String, CaseIterable, Identifiable, Sendable {
    case recommended, review, keep
    public var id: Self { self }
    public var title: String {
        switch self {
        case .recommended: L10n.text("Khuyên dọn")
        case .review: L10n.text("Cần xem lại")
        case .keep: L10n.text("Không nên xóa")
        }
    }
    public var explanation: String {
        switch self {
        case .recommended: L10n.text("Có thể tạo lại theo quy tắc cache/log/build; vẫn có rủi ro mất dữ liệu offline hoặc phải tải lại. Không chứng minh tệp đã hết dùng.")
        case .review: L10n.text("Có thể chọn trong phạm vi cho phép, nhưng có thể chứa dữ liệu hoặc thiết lập quan trọng. Tự kiểm tra trước khi chọn.")
        case .keep: L10n.text("Chỉ phân tích; khóa dọn đối với dữ liệu hệ thống, dùng chung hoặc chưa đủ điều kiện an toàn.")
        }
    }
}

public struct RelatedApplicationFile: Identifiable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let snapshot: FileSnapshot
    public let recommendation: CleanupRecommendation
    public let reasonText: LocalizedText
    public var reason: String { reasonText.localized() }
    public var bytes: Int64 { snapshot.size }
    public var canTrash: Bool { recommendation != .keep }
}

struct ApplicationBundleSnapshot: Equatable, Sendable {
    let entries: [String: FileSnapshot]
    let bytes: Int64
}

public struct ApplicationRemovalPlan: Identifiable, Sendable {
    public let id = UUID()
    public let application: InstalledApplication
    let bundleSnapshot: ApplicationBundleSnapshot?
    public let files: [RelatedApplicationFile]
    public let warnings: [ScanWarning]
    public let protectionText: LocalizedText?
    public var protectionReason: String? { protectionText?.localized() }
    public let limited: Bool
    public let cancelled: Bool
    public var applicationBytes: Int64 { bundleSnapshot?.bytes ?? 0 }
    public var canRemoveApplication: Bool { protectionText == nil && bundleSnapshot != nil && !cancelled }
}

public struct ApplicationRemovalReport: Sendable {
    public var applicationMoved = false
    public var applicationBytes: Int64 = 0
    public var movedFiles: [RelatedApplicationFile] = []
    public var failures: [CleanupFailure] = []
    public var bytes: Int64 { applicationBytes + movedFiles.reduce(0) { $0 + $1.bytes } }
    public init() {}
}

import Foundation

public enum ScanMode: String, CaseIterable, Sendable, Identifiable {
    case quick, deep
    public var id: Self { self }
    public var title: String { self == .quick ? L10n.text("Quét nhanh") : L10n.text("Quét sâu toàn ổ") }
}

public enum CleanupCategory: String, CaseIterable, Sendable, Identifiable {
    case caches, logs, developer, installers, largeFiles, appLeftovers, systemFiles
    public var id: Self { self }

    public var title: String {
        switch self {
        case .caches: L10n.text("Cache cũ")
        case .logs: L10n.text("Log cũ")
        case .developer: L10n.text("Build Xcode")
        case .installers: L10n.text("Bộ cài cũ")
        case .largeFiles: L10n.text("Tệp lớn")
        case .appLeftovers: L10n.text("Dữ liệu app còn sót")
        case .systemFiles: L10n.text("Phân tích toàn ổ")
        }
    }

    public var symbol: String {
        switch self {
        case .caches: "shippingbox"
        case .logs: "doc.text"
        case .developer: "hammer"
        case .installers: "shippingbox.and.arrow.backward"
        case .largeFiles: "doc.zipper"
        case .appLeftovers: "app.badge.checkmark"
        case .systemFiles: "internaldrive"
        }
    }

    public var reason: String {
        switch self {
        case .caches: L10n.text("Cache không sửa đổi ít nhất 14 ngày. Ứng dụng có thể phải tải hoặc tạo lại dữ liệu.")
        case .logs: L10n.text("Log không sửa đổi ít nhất 14 ngày. Có thể còn cần để chẩn đoán lỗi.")
        case .developer: L10n.text("Tệp trong Xcode DerivedData không sửa đổi ít nhất 30 ngày. Build tiếp theo có thể chậm hơn.")
        case .installers: L10n.text("Bộ cài trong Downloads không sửa đổi ít nhất 30 ngày. Kiểm tra bản cài trước khi dọn.")
        case .largeFiles: L10n.text("Tệp từ 100 MB. Kích thước không có nghĩa là rác. Chỉ dọn khi bạn chắc chắn không cần.")
        case .appLeftovers: L10n.text("Nghi dữ liệu còn sót theo bundle ID. Không thấy ứng dụng không chứng minh ứng dụng đã gỡ. Xem bằng chứng từng tệp.")
        case .systemFiles: L10n.text("Tệp từ 10 MB trên ổ khởi động. Chỉ phân tích và mở Finder, không cho dọn dữ liệu hệ thống hoặc tệp ngoài phạm vi an toàn.")
        }
    }
}

public struct FileSnapshot: Equatable, Sendable {
    public let device: Int32
    public let inode: UInt64
    public let size: Int64
    public let modifiedSeconds: Int64
    public let modifiedNanos: Int64
    public let changedSeconds: Int64
    public let changedNanos: Int64

    public var modifiedAt: Date {
        Date(timeIntervalSince1970: Double(modifiedSeconds) + Double(modifiedNanos) / 1_000_000_000)
    }
}

public struct ScanItem: Identifiable, Equatable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let category: CleanupCategory
    public let snapshot: FileSnapshot
    public let applicationID: String?
    public let evidenceText: [LocalizedText]?
    public var evidence: String? { evidenceText?.map { $0.localized() }.joined(separator: " ") }
    public let isReadOnly: Bool
    public var bytes: Int64 { snapshot.size }
    public var canTrash: Bool { category != .systemFiles && !isReadOnly }
    public var reason: String { evidence ?? category.reason }
    public var recommendation: CleanupRecommendation {
        guard canTrash else { return .keep }
        switch category {
        case .caches, .logs, .developer: return .recommended
        case .installers, .largeFiles, .appLeftovers: return .review
        case .systemFiles: return .keep
        }
    }

    init(url: URL, category: CleanupCategory, snapshot: FileSnapshot,
         applicationID: String? = nil, evidence: [LocalizedText]? = nil, isReadOnly: Bool = false) {
        self.url = url
        self.category = category
        self.snapshot = snapshot
        self.applicationID = applicationID
        self.evidenceText = evidence
        self.isReadOnly = isReadOnly
    }
}

public struct ScanWarning: Identifiable, Sendable {
    public var id: String { path + messageText.source }
    public let path: String
    public let messageText: LocalizedText
    public var message: String { messageText.localized() }
}

public struct FolderUsage: Identifiable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public var bytes: Int64 = 0
    public var fileCount = 0
    public var canTrash: Bool { false }
}

public struct ScanReport: Sendable {
    public var items: [ScanItem] = []
    public var warnings: [ScanWarning] = []
    public var visitedFiles = 0
    public var visitedDirectories = 0
    public var scannedBytes: Int64 = 0
    public var readErrors = 0
    public var folderUsages: [FolderUsage] = []
    public var folderSummaryLimited = false
    public var cancelled = false
    public var limited = false
    public var applicationCount: Int?
    public var deepScanCompleted = false
    public var bytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
    public var cleanupBytes: Int64 { items.filter(\.canTrash).reduce(0) { $0 + $1.bytes } }
    public var leftoverApplicationCount: Int { Set(items.compactMap(\.applicationID)).count }
    var preview: Self {
        var result = self
        result.items = Array(items.sorted { $0.bytes == $1.bytes ? $0.id < $1.id : $0.bytes > $1.bytes }.prefix(500))
        return result
    }
    public init() {}
}

public struct ScanProgress: Sendable {
    public let visitedFiles: Int
    public let foundFiles: Int
    public let category: CleanupCategory
    public var currentPath: String? = nil
}

public struct CleanupFailure: Identifiable, Sendable {
    public var id: String { path }
    public let path: String
    public let messageText: LocalizedText
    public var message: String { messageText.localized() }
}

public struct CleanupReport: Sendable {
    public var moved: [ScanItem] = []
    public var failures: [CleanupFailure] = []
    public var bytes: Int64 { moved.reduce(0) { $0 + $1.bytes } }
    public init() {}
}

public struct DiskSpace: Sendable {
    public let total: Int64
    public let available: Int64

    public static func read(at url: URL) throws -> Self {
        let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        guard let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity, total > 0 else {
            throw CocoaError(.fileReadUnknown)
        }
        return Self(total: Int64(total), available: Int64(available))
    }
}

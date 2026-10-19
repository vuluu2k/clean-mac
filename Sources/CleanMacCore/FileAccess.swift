import Darwin
import Foundation

struct FileMetadata {
    let snapshot: FileSnapshot
    let isRegular: Bool
    let isDirectory: Bool
    let isSymbolicLink: Bool
    let linkCount: UInt16
    let isDataless: Bool

    static func read(_ url: URL) throws -> Self {
        var value = stat()
        guard lstat(url.path, &value) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: url.path])
        }
        let type = value.st_mode & S_IFMT
        return Self(
            snapshot: FileSnapshot(
                device: value.st_dev, inode: value.st_ino, size: value.st_size,
                modifiedSeconds: Int64(value.st_mtimespec.tv_sec), modifiedNanos: Int64(value.st_mtimespec.tv_nsec),
                changedSeconds: Int64(value.st_ctimespec.tv_sec), changedNanos: Int64(value.st_ctimespec.tv_nsec)
            ),
            isRegular: type == S_IFREG, isDirectory: type == S_IFDIR,
            isSymbolicLink: type == S_IFLNK, linkCount: value.st_nlink,
            isDataless: value.st_flags & UInt32(SF_DATALESS) != 0
        )
    }
}

public enum SafetyError: LocalizedError {
    case outsideScope, unsafePath, changedFile, notEligible, tooManyFiles, readOnly, cancelled, incompleteInspection

    public var errorDescription: String? { localizedText.localized() }
    public var localizedText: LocalizedText {
        switch self {
        case .outsideScope: .init("Đường dẫn nằm ngoài phạm vi được phép.")
        case .unsafePath: .init("Bỏ qua liên kết, package, tệp cloud hoặc đường dẫn được bảo vệ.")
        case .changedFile: .init("Tệp đã thay đổi sau lần quét. Hãy quét lại.")
        case .notEligible: .init("Tệp không còn đáp ứng quy tắc dọn dẹp. Hãy quét lại.")
        case .tooManyFiles: .init("Danh sách vượt giới hạn 20.000 tệp mỗi lượt.")
        case .readOnly: .init("Mục chỉ được phân tích, không được phép chuyển vào Trash.")
        case .cancelled: .init("Đã dừng phân tích. Không thực hiện gỡ ứng dụng.")
        case .incompleteInspection: .init("Không kiểm tra được đầy đủ ứng dụng trong giới hạn an toàn. Hãy kiểm tra bằng Finder hoặc trình gỡ của nhà phát hành.")
        }
    }
}

struct ScanRoot: Sendable {
    let url: URL
    let category: CleanupCategory
}

public struct ScanPolicy: Sendable {
    public let home: URL
    public let reviewFolders: [URL]
    public static let largeFileBytes: Int64 = 10_000_000
    static let packageExtensions: Set<String> = [
        "app", "bundle", "framework", "plugin", "photoslibrary", "photolibrary", "musiclibrary",
        "xcodeproj", "xcworkspace", "playground", "sparsebundle", "backupbundle"
    ]

    static func isProtectedFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased().split(separator: "-").first.map(String.init) ?? ""
        return ["db", "sqlite", "sqlite3", "keychain", "keychain-db", "download", "crdownload", "part", "partial"].contains(ext)
    }

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser, reviewFolders: [URL] = []) {
        self.home = home.resolvingSymlinksInPath().standardizedFileURL
        self.reviewFolders = reviewFolders.map(\.standardizedFileURL)
    }

    var defaultRoots: [ScanRoot] {
        [
            ScanRoot(url: home.appendingPathComponent("Library/Caches"), category: .caches),
            ScanRoot(url: home.appendingPathComponent("Library/Logs"), category: .logs),
            ScanRoot(url: home.appendingPathComponent("Library/Developer/Xcode/DerivedData"), category: .developer),
            ScanRoot(url: home.appendingPathComponent("Downloads"), category: .largeFiles)
        ]
    }

    var roots: [ScanRoot] {
        defaultRoots + reviewFolders.map { ScanRoot(url: $0, category: .largeFiles) }
    }

    static func contains(_ parent: URL, _ child: URL) -> Bool {
        child.path != parent.path && child.path.hasPrefix(parent.path == "/" ? "/" : parent.path + "/")
    }

    public func validateReviewFolder(_ url: URL) throws {
        let folder = url.standardizedFileURL
        guard Self.contains(home, folder) else { throw SafetyError.outsideScope }
        // Default macOS volumes ignore case, so "library" must be protected too.
        let firstComponent = folder.pathComponents.dropFirst(home.pathComponents.count).first ?? ""
        guard firstComponent.caseInsensitiveCompare("Library") != .orderedSame else { throw SafetyError.outsideScope }
        try validatePath(folder)
        guard try FileMetadata.read(folder).isDirectory else { throw SafetyError.unsafePath }
    }

    func validatePath(_ url: URL, beneath base: URL? = nil) throws {
        let base = base ?? home
        guard url.isFileURL, Self.contains(base, url) else { throw SafetyError.outsideScope }
        let components = url.pathComponents.dropFirst(base.pathComponents.count)
        var current = base
        guard try FileMetadata.read(base).isDirectory else { throw SafetyError.unsafePath }
        for component in components {
            guard !component.hasPrefix(".") else { throw SafetyError.unsafePath }
            current.appendPathComponent(component)
            let metadata = try FileMetadata.read(current)
            guard !metadata.isSymbolicLink, !metadata.isDataless else { throw SafetyError.unsafePath }
            let values = try current.resourceValues(forKeys: [.isPackageKey, .isAliasFileKey, .isUbiquitousItemKey])
            guard values.isPackage != true, values.isAliasFile != true, values.isUbiquitousItem != true,
                  !Self.packageExtensions.contains(current.pathExtension.lowercased()) else { throw SafetyError.unsafePath }
        }
    }

    func validateRoot(_ root: ScanRoot) throws {
        if !defaultRoots.contains(where: { $0.url == root.url }) { try validateReviewFolder(root.url) }
        try validatePath(root.url)
    }

    func candidate(at url: URL, now: Date, checkAncestors: Bool = true) throws -> ScanItem? {
        let url = url.standardizedFileURL
        guard let root = roots.first(where: { Self.contains($0.url, url) }) else { throw SafetyError.outsideScope }
        // Review folders cannot grant access to protected Library paths.
        if checkAncestors {
            try validateRoot(root)
            try validatePath(url)
        }
        let metadata = try FileMetadata.read(url)
        guard metadata.isRegular, metadata.linkCount == 1, !metadata.isDataless,
              metadata.snapshot.size > 0, !Self.isProtectedFile(url) else { return nil }
        let age = now.timeIntervalSince(metadata.snapshot.modifiedAt)
        let category: CleanupCategory
        switch root.category {
        case .caches, .logs:
            guard age >= 14 * 86_400 else { return nil }
            category = root.category
        case .developer:
            guard age >= 30 * 86_400 else { return nil }
            category = .developer
        case .largeFiles, .installers:
            if Self.contains(home.appendingPathComponent("Downloads"), url),
               ["dmg", "pkg", "mpkg"].contains(url.pathExtension.lowercased()), age >= 30 * 86_400 {
                category = .installers
            } else {
                guard metadata.snapshot.size >= Self.largeFileBytes else { return nil }
                category = .largeFiles
            }
        case .appLeftovers, .systemFiles:
            return nil
        }
        return ScanItem(url: url, category: category, snapshot: metadata.snapshot)
    }
}

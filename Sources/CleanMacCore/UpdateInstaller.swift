import CryptoKit
import Foundation
import Security

public enum UpdateInstallError: Error, Equatable, Sendable {
    case unsupportedLocation, downloadFailed, checksumMismatch, mountFailed, invalidApplication
}

/// Installs a GitHub release only after an explicit click: download, SHA-256, bundle ID, version and
/// signature checks, then an atomic swap that keeps the previous app in Trash.
public struct UpdateInstaller: Sendable {
    public static let bundleIdentifier = "app.cleanmac.local"
    static let maximumImageBytes = 200_000_000
    private let fetch: @Sendable (URL, Int) async throws -> URL
    private let attach: @Sendable (URL) throws -> URL
    private let detach: @Sendable (URL) -> Void
    private let trash: @Sendable (URL) throws -> Void

    public init() {
        fetch = Self.download
        attach = Self.attachImage
        detach = Self.detachImage
        trash = { try FileManager().trashItem(at: $0, resultingItemURL: nil) }
    }

    init(fetch: @escaping @Sendable (URL, Int) async throws -> URL, attach: @escaping @Sendable (URL) throws -> URL,
         detach: @escaping @Sendable (URL) -> Void, trash: @escaping @Sendable (URL) throws -> Void) {
        self.fetch = fetch
        self.attach = attach
        self.detach = detach
        self.trash = trash
    }

    /// The running bundle, when it sits in an Applications folder this user can write to.
    public static func installTarget(bundle: URL, home: URL) -> URL? {
        let bundle = bundle.resolvingSymlinksInPath().standardizedFileURL
        let parent = bundle.deletingLastPathComponent().path
        let allowed = ["/Applications", home.resolvingSymlinksInPath().appendingPathComponent("Applications").standardizedFileURL.path]
        guard bundle.lastPathComponent == "clean-mac.app", allowed.contains(parent),
              FileManager.default.isWritableFile(atPath: parent) else { return nil }
        return bundle
    }

    public func install(_ release: ReleaseUpdate, replacing target: URL) async throws -> URL {
        let version = release.version.description
        let name = "clean-mac-\(version)-universal.dmg"
        let base = URL(string: "https://github.com/vuluu2k/clean-mac/releases/download/v\(version)/")!
        let fm = FileManager()
        // Downloads, the mount point and staging are this installer's own temporary files.
        let sums = try await fetch(base.appendingPathComponent("SHA256SUMS"), 4_096)
        defer { try? fm.removeItem(at: sums) }
        guard let text = try? String(contentsOf: sums, encoding: .utf8),
              let expected = Self.checksum(for: name, in: text) else { throw UpdateInstallError.checksumMismatch }
        let image = try await fetch(base.appendingPathComponent(name), Self.maximumImageBytes)
        defer { try? fm.removeItem(at: image) }
        guard try Self.sha256(of: image) == expected else { throw UpdateInstallError.checksumMismatch }
        let mount = try attach(image)
        defer { detach(mount) }
        let mounted = mount.appendingPathComponent("clean-mac.app")
        try Self.validateApplication(at: mounted, version: version)
        let stagingFolder = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: target, create: true)
        defer { try? fm.removeItem(at: stagingFolder) }
        let staging = stagingFolder.appendingPathComponent("clean-mac.app")
        try fm.copyItem(at: mounted, to: staging)
        try Self.validateApplication(at: staging, version: version)
        let backupName = "clean-mac \(UUID().uuidString.prefix(8)).app"
        _ = try fm.replaceItemAt(target, withItemAt: staging, backupItemName: backupName, options: .withoutDeletingBackupItem)
        // The previous app goes to Trash so it can be put back; if that fails it stays beside the new one.
        try? trash(target.deletingLastPathComponent().appendingPathComponent(backupName))
        return target
    }

    static func checksum(for name: String, in sums: String) -> String? {
        for line in sums.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: " ")
            if parts.count == 2, parts[1] == name, parts[0].count == 64, parts[0].allSatisfy(\.isHexDigit) {
                return parts[0].lowercased()
            }
        }
        return nil
    }

    static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func validateApplication(at url: URL, version: String) throws {
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard values.isSymbolicLink != true, values.isDirectory == true,
              let info = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")),
              info["CFBundleIdentifier"] as? String == bundleIdentifier,
              info["CFBundleShortVersionString"] as? String == version else { throw UpdateInstallError.invalidApplication }
        var code: SecStaticCode?
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecStaticCodeCheckValidity(code, flags, nil) == errSecSuccess else { throw UpdateInstallError.invalidApplication }
    }

    // ponytail: size is checked after the download finishes; stream with a delegate if releases ever get large.
    static func download(_ url: URL, maximumBytes: Int) async throws -> URL {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        let session = URLSession(configuration: configuration, delegate: GitHubDownloadRedirects(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("clean-mac", forHTTPHeaderField: "User-Agent")
        let (temporary, response) = try await session.download(for: request)
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("clean-mac-update-\(UUID().uuidString)-\(url.lastPathComponent)")
        try FileManager.default.moveItem(at: temporary, to: destination)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let size = try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= maximumBytes else {
            try? FileManager.default.removeItem(at: destination)
            throw UpdateInstallError.downloadFailed
        }
        return destination
    }

    static func attachImage(_ image: URL) throws -> URL {
        let mount = FileManager.default.temporaryDirectory.appendingPathComponent("clean-mac-update-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: false)
        do { try hdiutil(["attach", "-readonly", "-nobrowse", "-noautoopen", "-mountpoint", mount.path, image.path]) }
        catch { try? FileManager.default.removeItem(at: mount); throw error }
        return mount
    }

    static func detachImage(_ mount: URL) {
        // An empty mount point is removed; a still-mounted volume is not a directory remove() can take.
        if (try? hdiutil(["detach", mount.path])) != nil { try? FileManager.default.removeItem(at: mount) }
    }

    private static func hdiutil(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        try process.run()
        guard finished.wait(timeout: .now() + 60) == .success else { process.terminate(); throw UpdateInstallError.mountFailed }
        guard process.terminationStatus == 0 else { throw UpdateInstallError.mountFailed }
    }
}

/// Release assets redirect from github.com to GitHub's asset hosts; nothing else is followed.
private final class GitHubDownloadRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        let host = request.url?.host ?? ""
        let trusted = request.url?.scheme == "https" && ["github.com", "objects.githubusercontent.com", "release-assets.githubusercontent.com"].contains(host)
        completionHandler(trusted ? request : nil)
    }
}

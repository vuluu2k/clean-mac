import Foundation

public struct ReleaseVersion: Comparable, Sendable, CustomStringConvertible {
    private let parts: [Int]
    public var description: String { parts.map(String.init).joined(separator: ".") }

    public init?(_ value: String) {
        guard value.utf8.count <= 64 else { return nil }
        let version = value.hasPrefix("v") ? value.dropFirst() : value[...]
        let components = version.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3 else { return nil }
        var numbers: [Int] = []
        for component in components {
            guard !component.isEmpty, component.utf8.allSatisfy({ (48...57).contains($0) }),
                  component.count == 1 || component.first != "0", let number = Int(component) else { return nil }
            numbers.append(number)
        }
        parts = numbers
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
}

public struct ReleaseUpdate: Equatable, Sendable {
    public let version: ReleaseVersion
    public let url: URL
}

public enum UpdateCheckError: Error, Equatable, Sendable { case invalidVersion, invalidResponse }

public struct UpdateChecker: Sendable {
    public static let latestURL = URL(string: "https://api.github.com/repos/vuluu2k/clean-mac/releases/latest")!
    private static let maximumBytes = 262_144
    private let fetch: @Sendable () async throws -> (Data, HTTPURLResponse)

    public init() { fetch = Self.fetchLatest }
    init(fetch: @escaping @Sendable () async throws -> (Data, HTTPURLResponse)) { self.fetch = fetch }

    public func check(currentVersion: String) async throws -> ReleaseUpdate? {
        guard let current = ReleaseVersion(currentVersion) else { throw UpdateCheckError.invalidVersion }
        let (data, response) = try await fetch()
        guard response.statusCode == 200, response.url == Self.latestURL, data.count <= Self.maximumBytes,
              let release = try? JSONDecoder().decode(GitHubRelease.self, from: data),
              !release.draft, !release.prerelease, let version = ReleaseVersion(release.tag_name),
              let url = URL(string: "https://github.com/vuluu2k/clean-mac/releases/tag/\(release.tag_name)") else {
            throw UpdateCheckError.invalidResponse
        }
        return version > current ? ReleaseUpdate(version: version, url: url) : nil
    }

    private struct GitHubRelease: Decodable {
        let tag_name: String
        let draft: Bool
        let prerelease: Bool
    }

    private static func fetchLatest() async throws -> (Data, HTTPURLResponse) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        let session = URLSession(configuration: configuration, delegate: RejectRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: latestURL, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("clean-mac", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.url == latestURL,
              http.expectedContentLength <= Int64(maximumBytes) else { throw UpdateCheckError.invalidResponse }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maximumBytes else { throw UpdateCheckError.invalidResponse }
            data.append(byte)
        }
        return (data, http)
    }
}

private final class RejectRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

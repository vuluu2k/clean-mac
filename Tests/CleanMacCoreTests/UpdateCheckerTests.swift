import Foundation
import Testing
@testable import CleanMacCore

@Test func releaseVersionsUseNumericStableOrdering() throws {
    #expect(try #require(ReleaseVersion("0.10.0")) > #require(ReleaseVersion("0.9.99")))
    #expect(ReleaseVersion("v1.2.3") == ReleaseVersion("1.2.3"))
    for value in ["", "1.2", "1.2.3.4", "1.2.3-beta", "1.2.3+dev", "01.2.3", "-1.2.3", "1. 2.3", "vv1.2.3", "１.2.3", String(repeating: "9", count: 80)] {
        #expect(ReleaseVersion(value) == nil, "Reject \(value)")
    }
}

@Test func checksOnlyNewerStableReleasesAndBuildsTrustedLinks() async throws {
    let newer = try #require(try await fixtureChecker(tag: "v0.10.0").check(currentVersion: "0.9.0"))
    #expect(newer.version.description == "0.10.0")
    #expect(newer.url.absoluteString == "https://github.com/vuluu2k/clean-mac/releases/tag/v0.10.0")
    #expect(try await fixtureChecker(tag: "v0.9.0").check(currentVersion: "0.9.0") == nil)
    #expect(try await fixtureChecker(tag: "v0.8.0").check(currentVersion: "0.9.0") == nil)
    for tag in ["v1.0.0-beta", "../../other", "https://example.com", "v1.2.3?redirect=other"] {
        await #expect(throws: UpdateCheckError.invalidResponse) {
            try await fixtureChecker(tag: tag).check(currentVersion: "0.9.0")
        }
    }
}

@Test func rejectsReleaseFailuresAndUntrustedResponses() async {
    for checker in [fixtureChecker(tag: "v1.0.0", draft: true), fixtureChecker(tag: "v1.0.0", prerelease: true),
                    fixtureChecker(tag: "v1.0.0", status: 403), fixtureChecker(tag: "v1.0.0", status: 404),
                    fixtureChecker(tag: "v1.0.0", url: URL(string: "https://example.com/releases/latest")!)] {
        await #expect(throws: UpdateCheckError.invalidResponse) { try await checker.check(currentVersion: "0.9.0") }
    }
    await #expect(throws: UpdateCheckError.invalidVersion) {
        try await fixtureChecker(tag: "v1.0.0").check(currentVersion: "development")
    }
    for data in [Data("not JSON".utf8), Data(repeating: 65, count: 262_145)] {
        let checker = UpdateChecker(fetch: { (data, HTTPURLResponse(url: UpdateChecker.latestURL, statusCode: 200, httpVersion: nil, headerFields: nil)!) })
        await #expect(throws: UpdateCheckError.invalidResponse) { try await checker.check(currentVersion: "0.9.0") }
    }
    let offline = UpdateChecker(fetch: { throw URLError(.notConnectedToInternet) })
    await #expect(throws: URLError.self) { try await offline.check(currentVersion: "0.9.0") }
}

private func fixtureChecker(tag: String, draft: Bool = false, prerelease: Bool = false, status: Int = 200,
                            url: URL = UpdateChecker.latestURL) -> UpdateChecker {
    let data = try! JSONSerialization.data(withJSONObject: ["tag_name": tag, "draft": draft, "prerelease": prerelease,
        "html_url": "https://malicious.invalid/ignored", "body": "Ignored remote content"])
    return UpdateChecker(fetch: { (data, HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!) })
}

import Foundation
import Testing
@testable import CleanMacCore

// Opt-in network check against the published release: CLEAN_MAC_LIVE_UPDATE=1 swift test --filter liveRelease
@Test(.enabled(if: ProcessInfo.processInfo.environment["CLEAN_MAC_LIVE_UPDATE"] == "1"))
func liveReleaseInstallsIntoFixture() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("clean-mac-live-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let target = root.appendingPathComponent("Applications/clean-mac.app")
    try FileManager.default.createDirectory(at: target.appendingPathComponent("Contents"), withIntermediateDirectories: true)
    try Data("old".utf8).write(to: target.appendingPathComponent("Contents/old-marker"))
    let trashed = root.appendingPathComponent("FakeTrash")
    try FileManager.default.createDirectory(at: trashed, withIntermediateDirectories: true)
    let installer = UpdateInstaller(fetch: UpdateInstaller.download, attach: UpdateInstaller.attachImage, detach: UpdateInstaller.detachImage,
        trash: { try FileManager.default.moveItem(at: $0, to: trashed.appendingPathComponent($0.lastPathComponent)) })
    let release = ReleaseUpdate(version: ReleaseVersion("0.4.1")!, url: URL(string: "https://github.com/vuluu2k/clean-mac/releases/tag/v0.4.1")!)
    _ = try await installer.install(release, replacing: target)
    let info = NSDictionary(contentsOf: target.appendingPathComponent("Contents/Info.plist"))
    #expect(info?["CFBundleShortVersionString"] as? String == "0.4.1")
    try UpdateInstaller.validateApplication(at: target, version: "0.4.1")
}

import Foundation
import Testing
@testable import CleanMacCore

private func signedBundle(at url: URL, identifier: String = UpdateInstaller.bundleIdentifier, version: String) throws {
    let fm = FileManager.default
    try fm.createDirectory(at: url.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
    try PropertyListSerialization.data(fromPropertyList: [
        "CFBundleIdentifier": identifier, "CFBundleShortVersionString": version, "CFBundleExecutable": "CleanMac",
        "CFBundlePackageType": "APPL"], format: .xml, options: 0).write(to: url.appendingPathComponent("Contents/Info.plist"))
    try fm.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: url.appendingPathComponent("Contents/MacOS/CleanMac"))
    let codesign = Process()
    codesign.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    codesign.arguments = ["--force", "--sign", "-", url.path]
    codesign.standardError = FileHandle.nullDevice
    try codesign.run()
    codesign.waitUntilExit()
    #expect(codesign.terminationStatus == 0)
}

private final class Calls: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []
    func record(_ value: String) { lock.withLock { values.append(value) } }
    var all: [String] { lock.withLock { values } }
}

private struct InstallFixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("clean-mac-update-test-\(UUID().uuidString)")
    var target: URL { root.appendingPathComponent("Applications/clean-mac.app") }
    var mount: URL { root.appendingPathComponent("mount") }
    let release = ReleaseUpdate(version: ReleaseVersion("0.9.0")!, url: URL(string: "https://github.com/vuluu2k/clean-mac/releases/tag/v0.9.0")!)
    let calls = Calls()

    init(mountedIdentifier: String = UpdateInstaller.bundleIdentifier, mountedVersion: String = "0.9.0") throws {
        try signedBundle(at: target, version: "0.8.0")
        try signedBundle(at: mount.appendingPathComponent("clean-mac.app"), identifier: mountedIdentifier, version: mountedVersion)
        try Data("not really a disk image".utf8).write(to: root.appendingPathComponent("image.dmg"))
    }

    func installer(sums: String? = nil) throws -> UpdateInstaller {
        let image = root.appendingPathComponent("image.dmg")
        let checksum = try UpdateInstaller.sha256(of: image)
        let sumsFile = root.appendingPathComponent("SHA256SUMS")
        try Data((sums ?? "\(checksum)  clean-mac-0.9.0-universal.dmg\n").utf8).write(to: sumsFile)
        let calls = calls, mount = mount
        return UpdateInstaller(
            fetch: { url, _ in
                calls.record("fetch \(url.absoluteString)")
                let copy = FileManager.default.temporaryDirectory.appendingPathComponent("clean-mac-fetch-\(UUID().uuidString)")
                try FileManager.default.copyItem(at: url.lastPathComponent == "SHA256SUMS" ? sumsFile : image, to: copy)
                calls.record("copy \(copy.path)")
                return copy
            },
            attach: { _ in calls.record("attach"); return mount },
            detach: { _ in calls.record("detach") },
            trash: { url in calls.record("trash \(url.lastPathComponent)"); try FileManager.default.removeItem(at: url) })
    }

    func installedVersion() -> String? {
        NSDictionary(contentsOf: target.appendingPathComponent("Contents/Info.plist"))?["CFBundleShortVersionString"] as? String
    }
}

@Test func verifiedUpdateReplacesTheAppAndTrashesThePreviousOne() async throws {
    let f = try InstallFixture()
    defer { try? FileManager.default.removeItem(at: f.root) }
    let installed = try await f.installer().install(f.release, replacing: f.target)
    #expect(installed == f.target && f.installedVersion() == "0.9.0")
    let calls = f.calls.all
    #expect(calls.first == "fetch https://github.com/vuluu2k/clean-mac/releases/download/v0.9.0/SHA256SUMS")
    #expect(calls.contains("fetch https://github.com/vuluu2k/clean-mac/releases/download/v0.9.0/clean-mac-0.9.0-universal.dmg"))
    #expect(calls.contains("detach") && calls.contains { $0.hasPrefix("trash clean-mac ") })
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: f.target.deletingLastPathComponent().path)
    #expect(leftovers == ["clean-mac.app"])
}

@Test func rejectedUpdatesLeaveTheInstalledAppUntouched() async throws {
    let mismatch = try InstallFixture()
    defer { try? FileManager.default.removeItem(at: mismatch.root) }
    await #expect(throws: UpdateInstallError.checksumMismatch) {
        try await mismatch.installer(sums: "\(String(repeating: "0", count: 64))  clean-mac-0.9.0-universal.dmg\n").install(mismatch.release, replacing: mismatch.target)
    }
    #expect(!mismatch.calls.all.contains("attach"))
    await #expect(throws: UpdateInstallError.checksumMismatch) {
        try await mismatch.installer(sums: "garbage").install(mismatch.release, replacing: mismatch.target)
    }
    #expect(mismatch.installedVersion() == "0.8.0")

    for fixture in [try InstallFixture(mountedIdentifier: "com.example.other"), try InstallFixture(mountedVersion: "0.8.5")] {
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        await #expect(throws: UpdateInstallError.invalidApplication) {
            try await fixture.installer().install(fixture.release, replacing: fixture.target)
        }
        #expect(fixture.installedVersion() == "0.8.0" && fixture.calls.all.contains("detach"))
    }
}

@Test func unsignedOrTamperedBundlesFailValidation() throws {
    let f = try InstallFixture()
    defer { try? FileManager.default.removeItem(at: f.root) }
    let app = f.mount.appendingPathComponent("clean-mac.app")
    try UpdateInstaller.validateApplication(at: app, version: "0.9.0")
    try Data("tampered".utf8).write(to: app.appendingPathComponent("Contents/MacOS/CleanMac"))
    #expect(throws: UpdateInstallError.invalidApplication) { try UpdateInstaller.validateApplication(at: app, version: "0.9.0") }
}

@Test func checksumsAndInstallLocationsAreStrict() throws {
    let hash = String(repeating: "a", count: 64)
    #expect(UpdateInstaller.checksum(for: "x.dmg", in: "\(hash)  x.dmg\n") == hash)
    #expect(UpdateInstaller.checksum(for: "x.dmg", in: "\(hash)  y.dmg\n\(hash)  x.dmg.extra") == nil)
    #expect(UpdateInstaller.checksum(for: "x.dmg", in: "abc  x.dmg") == nil)
    let home = FileManager.default.temporaryDirectory.appendingPathComponent("clean-mac-home-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: home) }
    try FileManager.default.createDirectory(at: home.appendingPathComponent("Applications"), withIntermediateDirectories: true)
    let userApp = home.appendingPathComponent("Applications/clean-mac.app")
    #expect(UpdateInstaller.installTarget(bundle: userApp, home: home) == userApp.resolvingSymlinksInPath().standardizedFileURL)
    #expect(UpdateInstaller.installTarget(bundle: home.appendingPathComponent("Downloads/clean-mac.app"), home: home) == nil)
    #expect(UpdateInstaller.installTarget(bundle: home.appendingPathComponent("Applications/Other.app"), home: home) == nil)
}

@Test func installRemovesItsOwnDownloads() async throws {
    let f = try InstallFixture()
    defer { try? FileManager.default.removeItem(at: f.root) }
    _ = try await f.installer().install(f.release, replacing: f.target)
    let downloads = f.calls.all.filter { $0.hasPrefix("copy ") }.map { String($0.dropFirst(5)) }
    #expect(downloads.count == 2)
    for path in downloads { #expect(!FileManager.default.fileExists(atPath: path)) }
}

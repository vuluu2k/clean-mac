import Foundation
import Testing
@testable import CleanMacCore

@Test func leftoversUseExactBundleIDsAndDistinguishReadOnlyLocations() throws {
    let f = try Fixture()
    _ = try f.application("Applications/Live.app", id: "com.active.editor")
    let support = try f.file("Library/Application Support/com.retired.tool/offline.json")
    let prefs = try f.file("Library/Preferences/org.retired.player.plist")
    let database = try f.file("Library/Application Support/com.retired.tool/data.sqlite")
    let container = try f.file("Library/Containers/com.retired.tool/Data/Documents/note.txt")
    let agent = try f.file("Library/LaunchAgents/com.retired.helper.plist")
    let shared = try f.file("Volume/Library/Application Support/net.retired.shared/file")
    _ = try f.file("Library/Caches/com.active.editor/cache")
    _ = try f.file("Library/Caches/com.active.removed/cache")
    _ = try f.file("Library/Caches/com.apple.removed/cache")
    _ = try f.file("Library/Application Support/Friendly App Name/data")
    let inventory = ApplicationInventory.scan(roots: [f.home.appendingPathComponent("Applications")])
    let scanner = LeftoverScanner(policy: ScanPolicy(home: f.home), inventory: inventory,
        systemRoot: f.home.appendingPathComponent("Volume"), isRegistered: { _ in false })
    let report = scanner.scan()
    #expect(Set(report.items.map(\.url)) == [support, prefs, database, container, agent, shared])
    #expect(Set(report.items.filter(\.canTrash).map(\.url)) == [support, prefs])
    #expect(report.items.allSatisfy { $0.applicationID != nil && $0.reason.contains("Không thấy") })
    #expect(report.leftoverApplicationCount == 4)
}

@Test func registeredAppAndIncompleteInventoryFailClosed() throws {
    let f = try Fixture()
    let file = try f.file("Library/Application Support/com.retired.tool/data")
    let root = f.home.appendingPathComponent("Applications")
    try f.fm.createDirectory(at: root, withIntermediateDirectories: true)
    let policy = ScanPolicy(home: f.home)
    let volume = f.home.appendingPathComponent("Volume")
    let complete = ApplicationInventory.scan(roots: [root])
    #expect(LeftoverScanner(policy: policy, inventory: complete, systemRoot: volume, isRegistered: { _ in true }).scan().items.isEmpty)
    _ = try f.file("Applications/Broken.app/Contents/Info.plist")
    let incomplete = ApplicationInventory.scan(roots: [root])
    let report = LeftoverScanner(policy: policy, inventory: incomplete, systemRoot: volume, isRegistered: { _ in false }).scan()
    #expect(report.items.map(\.url) == [file])
    #expect(report.items.allSatisfy { !$0.canTrash })
}

@Test func leftoverScanDoesNotFollowSymlinkedOwnershipFolders() throws {
    let f = try Fixture()
    let outside = try f.file("Documents/private")
    try f.fm.createDirectory(at: f.home.appendingPathComponent("Library/Application Support"), withIntermediateDirectories: true)
    try f.fm.createSymbolicLink(at: f.home.appendingPathComponent("Library/Application Support/com.retired.tool"), withDestinationURL: outside.deletingLastPathComponent())
    let report = LeftoverScanner(policy: ScanPolicy(home: f.home), inventory: ApplicationInventory(),
        systemRoot: f.home.appendingPathComponent("Volume"), isRegistered: { _ in false }).scan()
    #expect(report.items.isEmpty)
}

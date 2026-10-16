import Foundation
import Testing
@testable import CleanMacCore

@Test func leftoverCleanupRechecksApplicationsInstalledAfterTheScan() throws {
    let f = try Fixture()
    let url = try f.file("Library/Application Support/com.retired.tool/offline.json")
    let policy = ScanPolicy(home: f.home)
    let volume = f.home.appendingPathComponent("Volume")
    let inventory = ApplicationInventory.scan(roots: [f.home.appendingPathComponent("Applications")])
    let item = try #require(LeftoverScanner(policy: policy, inventory: inventory, systemRoot: volume, isRegistered: { _ in false }).scan().items.first)
    var moved: [URL] = []
    let service = CleanupService(policy: policy, systemRoot: volume, isRegistered: { _ in false })
    #expect(service.moveToTrash([item], now: f.now) { moved.append($0) }.moved.count == 1)
    #expect(moved == [url])
    _ = try f.application("Applications/Reinstalled.app", id: "com.retired.tool")
    moved.removeAll()
    let result = service.moveToTrash([item], now: f.now) { moved.append($0) }
    #expect(moved.isEmpty && result.failures.count == 1)
    #expect(f.fm.fileExists(atPath: url.path))
}

@Test func readOnlyAndForgedContainerFindingsNeverReachTrash() throws {
    let f = try Fixture()
    let cache = try f.file("Library/Caches/ordinary")
    let container = try f.file("Library/Containers/com.retired.tool/Data/note.txt")
    let policy = ScanPolicy(home: f.home)
    let volume = f.home.appendingPathComponent("Volume")
    let system = ScanItem(url: cache, category: .systemFiles, snapshot: try FileMetadata.read(cache).snapshot)
    let forged = ScanItem(url: container, category: .appLeftovers, snapshot: try FileMetadata.read(container).snapshot,
        applicationID: "com.retired.tool", isReadOnly: false)
    var attempts = 0
    let result = CleanupService(policy: policy, systemRoot: volume, isRegistered: { _ in false })
        .moveToTrash([system, forged], now: f.now) { _ in attempts += 1 }
    #expect(attempts == 0 && result.failures.count == 2)
}

@Test func leftoverCleanupRejectsChangedParentsAndNewLaunchServicesRegistrations() throws {
    let f = try Fixture()
    let url = try f.file("Library/Application Support/com.retired.tool/data")
    let policy = ScanPolicy(home: f.home)
    let volume = f.home.appendingPathComponent("Volume")
    let item = try #require(LeftoverScanner(policy: policy, inventory: ApplicationInventory(), systemRoot: volume,
        isRegistered: { _ in false }).scan().items.first)
    var attempts = 0
    let registered = CleanupService(policy: policy, systemRoot: volume, isRegistered: { _ in true })
        .moveToTrash([item], now: f.now) { _ in attempts += 1 }
    #expect(registered.moved.isEmpty && registered.failures.count == 1)
    let parent = url.deletingLastPathComponent()
    let moved = f.home.appendingPathComponent("moved-data")
    try f.fm.moveItem(at: parent, to: moved)
    try f.fm.createSymbolicLink(at: parent, withDestinationURL: moved)
    let replaced = CleanupService(policy: policy, systemRoot: volume, isRegistered: { _ in false })
        .moveToTrash([item], now: f.now) { _ in attempts += 1 }
    #expect(attempts == 0 && replaced.failures.count == 1)
}

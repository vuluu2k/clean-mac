import Foundation
import Testing
@testable import CleanMacCore

@Test func changedMissingAndReplacedFilesNeverReachTrash() throws {
    let f = try Fixture()
    let modified = try f.file("Library/Caches/modified")
    let replaced = try f.file("Library/Caches/replaced")
    let missing = try f.file("Library/Caches/missing")
    let policy = ScanPolicy(home: f.home)
    let items = Scanner(policy: policy).scan(now: f.now).items
    try Data("changed content".utf8).write(to: modified)
    try f.fm.removeItem(at: replaced)
    try f.fm.createSymbolicLink(at: replaced, withDestinationURL: modified)
    try f.fm.removeItem(at: missing)
    var attempts = 0
    let report = CleanupService(policy: policy).moveToTrash(items, now: f.now) { _ in attempts += 1 }
    #expect(attempts == 0)
    #expect(report.moved.isEmpty)
    #expect(report.failures.count == 3)
}

@Test func sameSizeContentReplacementWithRestoredMtimeIsRejected() throws {
    let f = try Fixture()
    let url = try f.file("Library/Caches/rewrite")
    let policy = ScanPolicy(home: f.home)
    let item = try #require(Scanner(policy: policy).scan(now: f.now).items.first)
    try Data(repeating: 66, count: 16).write(to: url)
    try f.fm.setAttributes([.modificationDate: item.snapshot.modifiedAt], ofItemAtPath: url.path)
    var attempts = 0
    let report = CleanupService(policy: policy).moveToTrash([item], now: f.now) { _ in attempts += 1 }
    #expect(attempts == 0)
    #expect(report.failures.count == 1)
}

@Test func symlinkedParentAfterScanIsRejected() throws {
    let f = try Fixture()
    let url = try f.file("Library/Caches/app/old")
    let policy = ScanPolicy(home: f.home)
    let item = try #require(Scanner(policy: policy).scan(now: f.now).items.first)
    let originalParent = url.deletingLastPathComponent()
    let newParent = f.home.appendingPathComponent("moved-app")
    try f.fm.moveItem(at: originalParent, to: newParent)
    try f.fm.createSymbolicLink(at: originalParent, withDestinationURL: newParent)
    var attempts = 0
    let report = CleanupService(policy: policy).moveToTrash([item], now: f.now) { _ in attempts += 1 }
    #expect(attempts == 0)
    #expect(report.failures.count == 1)
}

@Test func partialTrashFailureIsReportedWithoutFallbackDeletion() throws {
    let f = try Fixture()
    let good = try f.file("Library/Caches/good")
    let blocked = try f.file("Library/Caches/blocked")
    let policy = ScanPolicy(home: f.home)
    let items = Scanner(policy: policy).scan(now: f.now).items
    let temporaryTrash = f.home.appendingPathComponent("test-trash")
    try f.fm.createDirectory(at: temporaryTrash, withIntermediateDirectories: true)
    let report = CleanupService(policy: policy).moveToTrash(items, now: f.now) { url in
        if url == blocked { throw CocoaError(.fileWriteNoPermission) }
        try f.fm.moveItem(at: url, to: temporaryTrash.appendingPathComponent(url.lastPathComponent))
    }
    #expect(report.moved.map(\.url) == [good])
    #expect(report.failures.map(\.path) == [blocked.path])
    #expect(f.fm.fileExists(atPath: blocked.path))
    #expect(f.fm.fileExists(atPath: temporaryTrash.appendingPathComponent("good").path))
}

@Test func forgedOutOfScopeItemAndChangedCategoryAreRejected() throws {
    let f = try Fixture()
    let outside = try f.file("Documents/private")
    _ = try f.file("Library/Caches/good")
    let policy = ScanPolicy(home: f.home)
    let item = try #require(Scanner(policy: policy).scan(now: f.now).items.first)
    let forged = ScanItem(url: outside, category: .caches, snapshot: try FileMetadata.read(outside).snapshot)
    let wrongCategory = ScanItem(url: item.url, category: .logs, snapshot: item.snapshot)
    var attempts = 0
    let report = CleanupService(policy: policy).moveToTrash([forged, wrongCategory], now: f.now) { _ in attempts += 1 }
    #expect(attempts == 0)
    #expect(report.failures.count == 2)
    let empty = CleanupService(policy: policy).moveToTrash([], now: f.now) { _ in attempts += 1 }
    #expect(empty.moved.isEmpty && empty.failures.isEmpty && attempts == 0)
}

@Test func newHardLinkAfterScanIsRejected() throws {
    let f = try Fixture()
    let file = try f.file("Library/Caches/item")
    let policy = ScanPolicy(home: f.home)
    let item = try #require(Scanner(policy: policy).scan(now: f.now).items.first)
    try f.fm.linkItem(at: file, to: f.home.appendingPathComponent("other-link"))
    var attempts = 0
    let report = CleanupService(policy: policy).moveToTrash([item], now: f.now) { _ in attempts += 1 }
    #expect(attempts == 0 && report.failures.count == 1)
}

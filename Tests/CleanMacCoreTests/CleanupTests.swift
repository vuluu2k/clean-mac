import Foundation
import Testing
@testable import CleanMacCore

@Test func movesOnlySelectedUnchangedFilesAndDeduplicates() throws {
    let f = try Fixture()
    let selected = try f.file("Library/Caches/selected")
    let untouched = try f.file("Library/Caches/untouched")
    let policy = ScanPolicy(home: f.home)
    let items = Scanner(policy: policy).scan(now: f.now).items
    let item = try #require(items.first { $0.url == selected })
    var moved: [URL] = []
    let report = CleanupService(policy: policy).moveToTrash([item, item], now: f.now) { moved.append($0) }
    #expect(moved == [selected])
    #expect(report.moved == [item])
    #expect(report.bytes == 16)
    #expect(report.failures.isEmpty)
    #expect(f.fm.fileExists(atPath: untouched.path))
}

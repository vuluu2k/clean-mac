import Foundation
import Testing
@testable import CleanMacCore

@Test func deepScanFindsFilesOutsideHomeAndProtectsPortableApplications() throws {
    let f = try Fixture()
    let home = f.home.appendingPathComponent("Users/tester")
    let large = try f.file("Library/large-system.bin", bytes: 100_000_000)
    let hidden = try f.file("Users/tester/.cache/large.bin", bytes: 100_000_000)
    _ = try f.file("dev/device", bytes: 100_000_000)
    _ = try f.file("Volumes/External/large.bin", bytes: 100_000_000)
    _ = try f.file("System/Volumes/Data/duplicate.bin", bytes: 100_000_000)
    _ = try f.file("Users/tester/.ssh/private", bytes: 100_000_000)
    _ = try f.application("Elsewhere/Portable.app", id: "com.portable.editor")
    _ = try f.file("Users/tester/Library/Preferences/com.portable.editor.plist")
    let leftover = try f.file("Users/tester/Library/Application Support/org.retired.tool/cache")
    let scanner = DeepScanner(policy: ScanPolicy(home: home), systemRoot: f.home, isRegistered: { _ in false })
    let report = scanner.scan(now: f.now)
    #expect(report.deepScanCompleted)
    #expect(report.applicationCount == 1)
    #expect(Set(report.items.map(\.url)) == [large, hidden, leftover])
    #expect(report.items.filter { $0.category == .systemFiles }.allSatisfy { !$0.canTrash })
    #expect(report.items.first { $0.url == leftover }?.canTrash == true)
    #expect(f.fm.fileExists(atPath: large.path) && f.fm.fileExists(atPath: leftover.path))
}

@Test func deepScanCancellationAndRootBoundaryAreExplicit() throws {
    let f = try Fixture()
    _ = try f.file("Users/tester/Library/Caches/old")
    let scanner = DeepScanner(policy: ScanPolicy(home: f.home.appendingPathComponent("Users/tester")),
        systemRoot: f.home, isRegistered: { _ in false })
    let report = scanner.scan(now: f.now, isCancelled: { true })
    #expect(report.cancelled && !report.deepScanCompleted)
    #expect(report.items.isEmpty)
    #expect(ScanPolicy.contains(URL(fileURLWithPath: "/"), URL(fileURLWithPath: "/Library/test")))
    #expect(!ScanPolicy.contains(f.home, URL(fileURLWithPath: f.home.path + "-sibling/file")))
}

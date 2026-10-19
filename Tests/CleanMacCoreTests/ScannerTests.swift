import Foundation
import Testing
@testable import CleanMacCore

final class Fixture {
    let home: URL
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let fm = FileManager.default

    init() throws {
        home = fm.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("clean-mac-test-\(UUID())")
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
    }

    deinit { try? fm.removeItem(at: home) }

    @discardableResult
    func file(_ path: String, daysOld: Double = 20, bytes: Int = 16) throws -> URL {
        let url = home.appendingPathComponent(path)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 65, count: min(bytes, 16)).write(to: url)
        if bytes > 16 {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.truncate(atOffset: UInt64(bytes))
        }
        try fm.setAttributes([.modificationDate: now.addingTimeInterval(-daysOld * 86_400)], ofItemAtPath: url.path)
        return url
    }
}

@Test func scansOnlyOldCachesWithoutChangingFiles() throws {
    let fixture = try Fixture()
    let old = try fixture.file("Library/Caches/example/old.cache")
    let fresh = try fixture.file("Library/Caches/example/fresh.cache", daysOld: 1)
    let document = try fixture.file("Documents/important.txt")
    let report = Scanner(policy: ScanPolicy(home: fixture.home)).scan(now: fixture.now)
    #expect(report.items.map(\.url) == [old])
    #expect(report.items.first?.category == .caches)
    #expect(fixture.fm.fileExists(atPath: fresh.path))
    #expect(fixture.fm.fileExists(atPath: document.path))
    #expect(try Data(contentsOf: old) == Data(repeating: 65, count: 16))
}

@Test func ageBoundaryAndCategories() throws {
    let f = try Fixture()
    let boundary = try f.file("Library/Caches/boundary", daysOld: 14)
    _ = try f.file("Library/Caches/too-new", daysOld: 13.999)
    _ = try f.file("Library/Caches/future", daysOld: -1)
    let log = try f.file("Library/Logs/app.log", daysOld: 14)
    let build = try f.file("Library/Developer/Xcode/DerivedData/project/build.o", daysOld: 30)
    _ = try f.file("Library/Developer/Xcode/DerivedData/project/fresh.o", daysOld: 29)
    let installer = try f.file("Downloads/old.dmg", daysOld: 30)
    _ = try f.file("Downloads/new.dmg", daysOld: 29)
    let large = try f.file("Downloads/large.zip", daysOld: 0, bytes: Int(ScanPolicy.largeFileBytes))
    _ = try f.file("Downloads/under.zip", bytes: Int(ScanPolicy.largeFileBytes) - 1)
    let report = Scanner(policy: ScanPolicy(home: f.home)).scan(now: f.now)
    let categories = Dictionary(uniqueKeysWithValues: report.items.map { ($0.url, $0.category) })
    #expect(categories == [boundary: .caches, log: .logs, build: .developer, installer: .installers, large: .largeFiles])
}

@Test func quickScanHasNoResultCapAndReachesEveryRoot() throws {
    let f = try Fixture()
    for index in 0..<20_050 { _ = try f.file("Library/Caches/many/\(index)", bytes: 1) }
    let late = try f.file("Downloads/late.zip", daysOld: 0, bytes: Int(ScanPolicy.largeFileBytes))
    let report = Scanner(policy: ScanPolicy(home: f.home)).scan(now: f.now)
    #expect(report.items.count == 20_051)
    #expect(report.items.contains { $0.url == late })
}

@Test func skipsSymlinksHardLinksHiddenFilesPackagesAndDatabases() throws {
    let f = try Fixture()
    let outside = try f.file("Documents/private.txt")
    let good = try f.file("Library/Caches/good")
    _ = try f.file("Library/Caches/.hidden")
    _ = try f.file("Library/Caches/tool.app/Contents/cache")
    _ = try f.file("Library/Caches/session.sqlite")
    _ = try f.file("Library/Caches/session.sqlite-wal")
    let link = f.home.appendingPathComponent("Library/Caches/linked")
    try f.fm.createSymbolicLink(at: link, withDestinationURL: outside)
    try f.fm.createSymbolicLink(at: f.home.appendingPathComponent("Library/Caches/linked-directory"), withDestinationURL: outside.deletingLastPathComponent())
    let hard = try f.file("Library/Caches/hard")
    try f.fm.linkItem(at: hard, to: f.home.appendingPathComponent("Library/Caches/hard-copy"))
    let report = Scanner(policy: ScanPolicy(home: f.home)).scan(now: f.now)
    #expect(report.items.map(\.url) == [good])
}

@Test func reviewFoldersAreExplicitBoundedAndDeduplicated() throws {
    let f = try Fixture()
    let large = try f.file("Projects/export.mov", bytes: 100_000_000)
    _ = try f.file("Documents/not-selected.mov", bytes: 100_000_000)
    let policy = ScanPolicy(home: f.home, reviewFolders: [large.deletingLastPathComponent(), large.deletingLastPathComponent()])
    #expect(throws: (any Error).self) { try policy.validateReviewFolder(f.home) }
    #expect(throws: (any Error).self) { try policy.validateReviewFolder(f.home.appendingPathComponent("Library")) }
    try f.fm.createDirectory(at: f.home.appendingPathComponent("Library"), withIntermediateDirectories: true)
    #expect(throws: (any Error).self) { try policy.validateReviewFolder(f.home.appendingPathComponent("Library", isDirectory: true)) }
    #expect(throws: (any Error).self) { try policy.validateReviewFolder(URL(fileURLWithPath: f.home.path + "-other")) }
    let report = Scanner(policy: policy).scan(now: f.now)
    #expect(report.items.map(\.url) == [large])
}

@Test func reviewCannotBypassLibraryProtectionWithDifferentCasing() throws {
    let f = try Fixture()
    _ = try f.file("Library/Application Support/important", bytes: 100_000_000)
    let alternate = f.home.appendingPathComponent("library", isDirectory: true)
    let policy = ScanPolicy(home: f.home, reviewFolders: [alternate])
    #expect(throws: (any Error).self) { try policy.validateReviewFolder(alternate) }
    #expect(Scanner(policy: policy).scan(now: f.now).items.isEmpty)
}

@Test func linkedRootIsNotTraversedAndCancellationIsVisible() throws {
    let f = try Fixture()
    let outside = try f.file("Documents/old.cache")
    try f.fm.createDirectory(at: f.home.appendingPathComponent("Library"), withIntermediateDirectories: true)
    try f.fm.createSymbolicLink(at: f.home.appendingPathComponent("Library/Caches"), withDestinationURL: outside.deletingLastPathComponent())
    let scanner = Scanner(policy: ScanPolicy(home: f.home))
    let report = scanner.scan(now: f.now)
    #expect(report.items.isEmpty)
    #expect(!report.warnings.isEmpty)
    let cancelled = scanner.scan(now: f.now, isCancelled: { true })
    #expect(cancelled.cancelled)
    #expect(cancelled.items.isEmpty)
}

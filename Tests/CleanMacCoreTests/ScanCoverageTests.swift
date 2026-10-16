import Foundation
import os
import Testing
@testable import CleanMacCore

@Test func largeFolderOfSmallFilesIsVisibleInCoverage() throws {
    let f = try Fixture()
    for index in 0..<12 {
        _ = try f.file("Users/tester/Projects/dependencies/file-\(index)", bytes: 9_000_000)
    }
    _ = try f.file("Users/tester/.ssh/secret", bytes: 100_000_000)
    _ = try f.file("Volumes/External/archive", bytes: 100_000_000)
    _ = try f.file("System/Volumes/Data/duplicate", bytes: 100_000_000)
    let home = f.home.appendingPathComponent("Users/tester")
    let report = DeepScanner(policy: ScanPolicy(home: home), systemRoot: f.home, isRegistered: { _ in false }).scan(now: f.now)
    #expect(report.visitedFiles == 12)
    #expect(report.items.isEmpty)
    #expect(report.scannedBytes == 108_000_000)
    let folder = try #require(report.folderUsages.first { $0.url.path == home.appendingPathComponent("Projects/dependencies").path })
    #expect(folder.bytes == 108_000_000 && folder.fileCount == 12)
    #expect(!folder.canTrash)
    #expect(report.visitedDirectories >= 4)
}

@Test func boundedResultsKeepLateLargeFiles() throws {
    let f = try Fixture()
    var results = LargestFileResults(limit: 2)
    for (index, bytes) in [10_000_000, 20_000_000, 300_000_000, 50_000_000, 400_000_000].enumerated() {
        let url = try f.file("files/\(index)", bytes: bytes)
        results.insert(ScanItem(url: url, category: .systemFiles, snapshot: try FileMetadata.read(url).snapshot))
    }
    #expect(results.largest.map(\.bytes) == [400_000_000, 300_000_000])
    #expect(results.count == 2 && results.limited)
}

@Test(arguments: [ScanMode.quick, .deep])
func liveScanSnapshotsArriveBeforeCompletion(mode: ScanMode) throws {
    let f = try Fixture()
    let prefix = mode == .deep ? "Users/tester/Projects" : "Library/Caches"
    for index in 0..<450 { _ = try f.file("\(prefix)/file-\(index)", bytes: 11_000_000) }
    let state = OSAllocatedUnfairLock(initialState: (stop: false, snapshots: [ScanReport]()))
    let cancelled: @Sendable () -> Bool = { state.withLock { $0.stop } }
    let receive: @Sendable (ScanReport) -> Void = { snapshot in
        if snapshot.visitedFiles > 0 {
            state.withLock { $0.snapshots.append(snapshot); $0.stop = true }
        }
    }
    let report: ScanReport
    if mode == .deep {
        report = DeepScanner(policy: ScanPolicy(home: f.home.appendingPathComponent("Users/tester")),
            systemRoot: f.home, isRegistered: { _ in false })
            .scan(now: f.now, isCancelled: cancelled, onSnapshot: receive)
    } else {
        report = Scanner(policy: ScanPolicy(home: f.home)).scan(now: f.now, isCancelled: cancelled, onSnapshot: receive)
    }
    let snapshots = state.withLock { $0.snapshots }
    #expect(!snapshots.isEmpty)
    #expect(snapshots.contains { !$0.items.isEmpty && $0.scannedBytes > 0 })
    #expect(report.cancelled && !report.deepScanCompleted)
    #expect(report.visitedFiles > 0 && report.visitedFiles < 450)
    #expect(snapshots.allSatisfy { !$0.deepScanCompleted && $0.items.count <= 500 })
}

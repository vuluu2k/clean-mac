import Foundation
import Testing
import CleanMacCore
@testable import CleanMac

@MainActor
@Test func selectionStartsEmptyAndConfirmationKeepsCapturedList() async throws {
    let f = try Fixture()
    let first = try f.file("Library/Caches/first")
    let second = try f.file("Library/Caches/second")
    for url in [first, second] {
        try f.fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -30 * 86_400)], ofItemAtPath: url.path)
    }
    let model = AppModel(home: f.home, systemRoot: f.home, trashOperation: { _ in Issue.record("Unexpected Trash call") })
    #expect(model.selectedIDs.isEmpty && !model.hasScanned)
    model.selectedIDs = ["stale-selection"]
    model.scan()
    #expect(model.selectedIDs.isEmpty)
    while model.busy { try await Task.sleep(for: .milliseconds(10)) }
    #expect(model.report.items.count == 2 && model.selectedIDs.isEmpty)
    model.query = "/first"
    model.selectVisible()
    #expect(model.selectedIDs == [first.path])
    model.prepareCleanup()
    let captured = try #require(model.confirmation)
    #expect(captured.items.map(\.url) == [first])
    model.selectedIDs = [second.path]
    #expect(captured.items.map(\.url) == [first])
    model.scan()
    #expect(!model.busy && model.confirmation?.id == captured.id)
    model.confirmation = nil
    model.clean(captured)
    #expect(!model.busy)
    #expect(f.fm.fileExists(atPath: first.path) && f.fm.fileExists(atPath: second.path))
}

@MainActor
@Test func emptySelectionCannotOpenCleanupConfirmation() {
    let model = AppModel(trashOperation: { _ in Issue.record("Unexpected Trash call") })
    model.prepareCleanup()
    #expect(model.confirmation == nil && !model.busy)
    #expect(bytesText(0) == "0 B")
}

@MainActor
@Test func deepModeNeverSelectsReadOnlyResultsAndSwitchingModesClearsState() async throws {
    let f = try Fixture()
    let system = try f.file("Library/system.bin", bytes: 100_000_000)
    let cleanable = try f.file("Users/tester/Library/Application Support/com.retired.tool/data")
    _ = try f.file("Users/tester/Library/Containers/com.retired.tool/Data/note")
    let model = AppModel(home: f.home.appendingPathComponent("Users/tester"), systemRoot: f.home,
        isRegistered: { _ in false }, trashOperation: { _ in Issue.record("Unexpected Trash call") })
    model.setScanMode(.deep)
    model.scan()
    model.setScanMode(.quick)
    #expect(model.scanMode == .deep)
    while model.busy { try await Task.sleep(for: .milliseconds(10)) }
    #expect(model.report.items.count == 3 && model.selectedItems.isEmpty)
    model.category = .systemFiles
    model.selectVisible()
    #expect(model.selectedIDs.isEmpty)
    model.selectedIDs = [system.path]
    model.prepareCleanup()
    #expect(model.confirmation == nil)
    model.selectedIDs.removeAll()
    model.category = .appLeftovers
    model.selectVisible()
    #expect(model.selectedItems.map(\.url) == [cleanable])
    model.setScanMode(.quick)
    #expect(model.report.items.isEmpty && model.selectedIDs.isEmpty && !model.hasScanned)
}

@MainActor
@Test func folderAnalysisCannotBecomeACleanupSelection() async throws {
    let f = try Fixture()
    for index in 0..<12 { _ = try f.file("Users/tester/Projects/dependencies/\(index)", bytes: 9_000_000) }
    let model = AppModel(home: f.home.appendingPathComponent("Users/tester"), systemRoot: f.home,
        isRegistered: { _ in false }, trashOperation: { _ in Issue.record("Unexpected Trash call") })
    model.setScanMode(.deep)
    model.scan()
    model.selectVisible()
    model.prepareCleanup()
    #expect(model.selectedItems.isEmpty && model.confirmation == nil)
    while model.busy { try await Task.sleep(for: .milliseconds(10)) }
    #expect(model.hasVisibleResults && model.report.items.isEmpty && !model.report.folderUsages.isEmpty)
    model.selectedIDs = Set(model.report.folderUsages.map(\.id))
    model.prepareCleanup()
    #expect(model.selectedItems.isEmpty && model.confirmation == nil)
    model.setScanMode(.quick)
    #expect(model.report.folderUsages.isEmpty && model.report.scannedBytes == 0 && !model.hasVisibleResults)
}

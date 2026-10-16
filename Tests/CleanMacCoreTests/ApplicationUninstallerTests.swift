import Foundation
import os
import Testing
@testable import CleanMacCore

@Test func reviewCapturesAnExplicitThirdPartyApplicationBundle() throws {
    let f = try Fixture()
    let url = try f.application("Applications/Example.app", id: "org.example.editor")
    _ = try f.file("Applications/Example.app/Contents/MacOS/editor", bytes: 1_000)
    let service = ApplicationUninstaller(policy: ScanPolicy(home: f.home.appendingPathComponent("Users/tester")),
        systemRoot: f.home, isRunning: { _ in false }, registeredURL: { _ in nil })
    let app = try #require(service.catalog().applications.first { $0.url.path == url.path })
    let plan = service.review(app, now: f.now)
    #expect(plan.canRemoveApplication)
    #expect(plan.applicationBytes >= 1_000)
    #expect(plan.files.isEmpty)
    #expect(f.fm.fileExists(atPath: url.path))
}

@Test func reviewMatchesExactAppFilesAndLocksSensitiveData() throws {
    let f = try Fixture()
    let url = try f.application("Applications/Example.app", id: "org.example.editor")
    let cache = try f.file("Users/tester/Library/Caches/org.example.editor/cache")
    let preferences = try f.file("Users/tester/Library/Preferences/org.example.editor.plist")
    let support = try f.file("Users/tester/Library/Application Support/org.example.editor/offline.txt")
    let database = try f.file("Users/tester/Library/Application Support/org.example.editor/profile.sqlite")
    let container = try f.file("Users/tester/Library/Containers/org.example.editor/Data/state")
    let shared = try f.file("Library/Preferences/org.example.editor.plist")
    _ = try f.file("Users/tester/Library/Application Support/Example/friendly-name")
    _ = try f.file("Users/tester/Library/Caches/org.other.editor/cache")
    let service = ApplicationUninstaller(policy: ScanPolicy(home: f.home.appendingPathComponent("Users/tester")), systemRoot: f.home,
        isRunning: { _ in false }, registeredURL: { _ in nil })
    let app = try #require(service.catalog().applications.first { $0.url.path == url.path })
    let plan = service.review(app, now: f.now)
    #expect(Set(plan.files.map(\.id)) == Set([cache, preferences, support, database, container, shared].map(\.path)))
    #expect(Set(plan.files.filter(\.canTrash).map(\.id)) == Set([cache, preferences, support].map(\.path)))
    #expect(plan.files.first { $0.id == cache.path }?.recommendation == .recommended)
    #expect(plan.files.first { $0.id == preferences.path }?.recommendation == .review)
    #expect(plan.files.first { $0.id == database.path }?.recommendation == .keep)
}

@Test func boundedAppDataTraversalDoesNotPretendToBeComplete() throws {
    let f = try Fixture()
    for index in 0..<10 { _ = try f.file("data/\(index)") }
    let status = FileTreeWalker.walk(at: f.home.appendingPathComponent("data"), maximumEntries: 3,
        isCancelled: { false }, visit: { _, _ in true }, onError: { _, _ in })
    #expect(status.limited && status.files == 3 && !status.cancelled)
}

@Test func appDataBudgetAlsoCountsSkippedHiddenNames() throws {
    let f = try Fixture()
    for index in 0..<10 { _ = try f.file("data/.hidden-\(index)") }
    let status = FileTreeWalker.walk(at: f.home.appendingPathComponent("data"), maximumEntries: 3,
        isCancelled: { false }, visit: { _, _ in true }, onError: { _, _ in })
    #expect(status.limited && status.entries == 3 && status.files == 0)
}

@Test func uninstallMovesAppFirstAndOnlyConfirmedData() throws {
    let f = try Fixture()
    let url = try f.application("Applications/Example.app", id: "org.example.editor")
    let cache = try f.file("Users/tester/Library/Caches/org.example.editor/cache")
    let preferences = try f.file("Users/tester/Library/Preferences/org.example.editor.plist")
    let database = try f.file("Users/tester/Library/Application Support/org.example.editor/profile.sqlite")
    let service = ApplicationUninstaller(policy: ScanPolicy(home: f.home.appendingPathComponent("Users/tester")), systemRoot: f.home,
        isRunning: { _ in false }, registeredURL: { _ in nil })
    let app = try #require(service.catalog().applications.first)
    let plan = service.review(app, now: f.now)
    let destination = f.home.appendingPathComponent("FakeTrash")
    try f.fm.createDirectory(at: destination, withIntermediateDirectories: true)
    var moved: [String] = []
    let report = service.uninstall(plan, selectedDataIDs: [cache.path], trash: { item in
        try f.fm.moveItem(at: item, to: destination.appendingPathComponent(UUID().uuidString))
        moved.append(item.path)
    })
    #expect(report.applicationMoved && report.failures.isEmpty)
    #expect(moved == [url.path, cache.path])
    #expect(report.movedFiles.map(\.id) == [cache.path])
    #expect(f.fm.fileExists(atPath: preferences.path) && f.fm.fileExists(atPath: database.path))
}

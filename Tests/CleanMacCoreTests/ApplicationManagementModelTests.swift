import Foundation
import Testing
import CleanMacCore
@testable import CleanMac

@MainActor
private func finish(_ model: AppModel) async throws {
    let deadline = ContinuousClock.now + .seconds(5)
    while model.busy && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
    try #require(!model.busy)
}

@MainActor
@Test func recommendationFiltersIntersectCategoryAndSearchWithoutSelecting() async throws {
    let f = try Fixture()
    let cache = try f.file("Users/tester/Library/Caches/old")
    try f.fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -30 * 86_400)], ofItemAtPath: cache.path)
    let review = try f.file("Users/tester/Downloads/review.bin", bytes: 100_000_000)
    let keep = try f.file("Library/locked.bin", bytes: 100_000_000)
    let model = AppModel(home: f.home.appendingPathComponent("Users/tester"), systemRoot: f.home,
        isRegistered: { _ in false }, trashOperation: { _ in Issue.record("Unexpected Trash call") })
    model.setScanMode(.deep)
    model.scan()
    try await finish(model)
    #expect(model.selectedIDs.isEmpty)
    model.recommendationFilter = .recommended
    #expect(model.filteredItems.map(\.id) == [cache.path])
    model.category = .systemFiles
    #expect(model.filteredItems.isEmpty)
    model.category = nil
    model.recommendationFilter = .keep
    #expect(model.filteredItems.map(\.id) == [keep.path])
    model.selectVisible()
    #expect(model.selectedIDs.isEmpty)
    model.recommendationFilter = .review
    model.query = "review.bin"
    #expect(model.filteredItems.map(\.id) == [review.path])
    model.selectVisible()
    #expect(model.selectedIDs == [review.path])
}

@MainActor
@Test func applicationReviewStartsEmptyAndCapturesOnlySelectedEligibleFiles() async throws {
    let f = try Fixture()
    let appURL = try f.application("Applications/Example.app", id: "org.example.editor")
    _ = try f.application("System/Applications/Protected.app", id: "com.apple.fixture")
    let cache = try f.file("Users/tester/Library/Caches/org.example.editor/cache")
    try f.fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -30 * 86_400)], ofItemAtPath: cache.path)
    let support = try f.file("Users/tester/Library/Application Support/org.example.editor/offline.txt")
    let database = try f.file("Users/tester/Library/Application Support/org.example.editor/profile.sqlite")
    let model = AppModel(home: f.home.appendingPathComponent("Users/tester"), systemRoot: f.home,
        isApplicationRunning: { _ in false }, registeredApplicationURL: { _ in nil },
        trashOperation: { _ in Issue.record("Unexpected Trash call") })
    model.scanApplications()
    try await finish(model)
    #expect(model.filteredApplications.count == 2)
    model.applicationFilter = .removable
    #expect(model.filteredApplications.map(\.id) == [appURL.path])
    model.applicationFilter = .keep
    #expect(model.filteredApplications.count == 1)
    model.applicationFilter = .all
    model.applicationQuery = "org.example"
    let app = try #require(model.filteredApplications.first)
    #expect(app.id == appURL.path)
    model.reviewApplication(app)
    try await finish(model)
    #expect(model.selectedRelatedIDs.isEmpty)
    model.selectRecommendedApplicationFiles()
    #expect(model.selectedRelatedIDs == [cache.path])
    model.selectedRelatedIDs.insert(database.path)
    model.prepareApplicationRemoval()
    let captured = try #require(model.applicationConfirmation)
    #expect(captured.files.map(\.id) == [cache.path])
    model.selectedRelatedIDs = [support.path]
    #expect(captured.files.map(\.id) == [cache.path])
    model.scan()
    model.scanApplications()
    #expect(!model.busy && model.applicationPlan?.id == captured.plan.id)
    model.applicationConfirmation = nil
    model.uninstallApplication(captured)
    #expect(!model.busy)
    #expect(f.fm.fileExists(atPath: appURL.path) && f.fm.fileExists(atPath: cache.path))
}

@MainActor
@Test func confirmedApplicationRemovalUsesInjectedTrashAndClearsStaleResults() async throws {
    let f = try Fixture()
    let appURL = try f.application("Applications/Example.app", id: "org.example.editor")
    let cache = try f.file("Users/tester/Library/Caches/org.example.editor/cache")
    let retained = try f.file("Users/tester/Library/Preferences/org.example.editor.plist")
    let destination = f.home.appendingPathComponent("FakeTrash")
    try f.fm.createDirectory(at: destination, withIntermediateDirectories: true)
    let model = AppModel(home: f.home.appendingPathComponent("Users/tester"), systemRoot: f.home,
        isApplicationRunning: { _ in false }, registeredApplicationURL: { _ in nil }, trashOperation: { item in
            try FileManager().moveItem(at: item, to: destination.appendingPathComponent(UUID().uuidString))
        })
    model.scanApplications()
    try await finish(model)
    let app = try #require(model.filteredApplications.first)
    model.reviewApplication(app)
    try await finish(model)
    model.selectedRelatedIDs = [cache.path]
    model.prepareApplicationRemoval()
    let captured = try #require(model.applicationConfirmation)
    model.selectedRelatedIDs = [retained.path]
    model.uninstallApplication(captured)
    try await finish(model)
    #expect(model.applicationRemovalReport?.applicationMoved == true)
    #expect(model.applicationRemovalReport?.movedFiles.map(\.id) == [cache.path])
    #expect(model.applicationPlan == nil && model.applicationConfirmation == nil && model.selectedRelatedIDs.isEmpty)
    #expect(model.applicationCatalog == nil && !model.hasVisibleResults)
    #expect(!f.fm.fileExists(atPath: appURL.path) && f.fm.fileExists(atPath: retained.path))
}

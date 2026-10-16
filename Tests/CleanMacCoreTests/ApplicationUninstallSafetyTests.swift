import Foundation
import os
import Testing
@testable import CleanMacCore

private func service(_ f: Fixture, running: @escaping @Sendable (InstalledApplication) -> Bool = { _ in false },
                     registered: @escaping @Sendable (String) -> URL? = { _ in nil }) -> ApplicationUninstaller {
    ApplicationUninstaller(policy: ScanPolicy(home: f.home.appendingPathComponent("Users/tester")),
        systemRoot: f.home, isRunning: running, registeredURL: registered)
}

@Test(arguments: ["apple", "system", "self", "portable", "running"])
func protectedApplicationsCannotGainRemovalFromForgedPlans(kind: String) throws {
    let f = try Fixture()
    let path = kind == "system" ? "System/Applications/Example.app" : kind == "portable" ? "Elsewhere/Example.app" : "Applications/Example.app"
    let id = kind == "apple" ? "com.apple.Example" : kind == "self" ? "app.cleanmac.local" : "org.example.editor"
    let url = try f.application(path, id: id)
    let app = try InstalledApplication.read(at: url)
    let uninstaller = service(f, running: { _ in kind == "running" })
    #expect(!uninstaller.review(app).canRemoveApplication)
    let forged = ApplicationRemovalPlan(application: app, bundleSnapshot: try ApplicationBundleSnapshot.capture(url),
        files: [], warnings: [], protectionText: nil, limited: false, cancelled: false)
    var calls = 0
    let result = uninstaller.uninstall(forged, selectedDataIDs: [], trash: { _ in calls += 1 })
    #expect(!result.applicationMoved && calls == 0 && !result.failures.isEmpty)
}

@Test func changedBundleDescendantBlocksRemovalWithoutRelyingOnRootDate() throws {
    let f = try Fixture()
    let url = try f.application("Applications/Example.app", id: "org.example.editor")
    let binary = try f.file("Applications/Example.app/Contents/MacOS/editor")
    let uninstaller = service(f)
    let plan = uninstaller.review(try InstalledApplication.read(at: url))
    try Data([1, 2, 3]).write(to: binary)
    #expect(try FileMetadata.read(url).snapshot == plan.application.snapshot)
    var calls = 0
    let result = uninstaller.uninstall(plan, selectedDataIDs: [], trash: { _ in calls += 1 })
    #expect(!result.applicationMoved && calls == 0)
}

@Test func applicationStartedAfterReviewBlocksRemoval() throws {
    let f = try Fixture()
    let url = try f.application("Applications/Example.app", id: "org.example.editor")
    let state = OSAllocatedUnfairLock(initialState: false)
    let uninstaller = service(f, running: { _ in state.withLock { $0 } })
    let plan = uninstaller.review(try InstalledApplication.read(at: url))
    #expect(plan.canRemoveApplication)
    state.withLock { $0 = true }
    let result = uninstaller.uninstall(plan, selectedDataIDs: [], trash: { _ in Issue.record("Running app reached Trash") })
    #expect(!result.applicationMoved && !result.failures.isEmpty)
}

@Test(arguments: ["same-id", "vendor", "registered-copy"])
func newAppCopiesOrFamiliesLockRelatedData(kind: String) throws {
    let f = try Fixture()
    let url = try f.application("Applications/Example.app", id: "org.example.editor")
    let cache = try f.file("Users/tester/Library/Caches/org.example.editor/cache")
    let other = f.home.appendingPathComponent(kind == "registered-copy" ? "Elsewhere/Other.app" : "Applications/Other.app")
    let uninstaller = service(f, registered: { _ in kind == "registered-copy" ? other : nil })
    let app = try InstalledApplication.read(at: url)
    let plan = uninstaller.review(app)
    #expect(plan.files.first?.canTrash == true)
    _ = try f.application(kind == "registered-copy" ? "Elsewhere/Other.app" : "Applications/Other.app",
        id: kind == "vendor" ? "org.example.helper" : "org.example.editor")
    var calls = 0
    let result = uninstaller.uninstall(plan, selectedDataIDs: [cache.path], trash: { _ in calls += 1 })
    #expect(!result.applicationMoved && calls == 0)
    #expect(uninstaller.review(app).files.allSatisfy { !$0.canTrash })
}

@Test(arguments: [true, false])
func nativeFailureNeverRemovesUnconfirmedDataOrFallsBack(failApplication: Bool) throws {
    let f = try Fixture()
    let url = try f.application("Applications/Example.app", id: "org.example.editor")
    let cache = try f.file("Users/tester/Library/Caches/org.example.editor/cache")
    let uninstaller = service(f)
    let plan = uninstaller.review(try InstalledApplication.read(at: url))
    let destination = f.home.appendingPathComponent("FakeTrash")
    try f.fm.createDirectory(at: destination, withIntermediateDirectories: true)
    var attempted: [String] = []
    let result = uninstaller.uninstall(plan, selectedDataIDs: [cache.path], trash: { item in
        attempted.append(item.path)
        if failApplication || item.path == cache.path { throw CocoaError(.fileWriteNoPermission) }
        try f.fm.moveItem(at: item, to: destination.appendingPathComponent(UUID().uuidString))
    })
    #expect(result.applicationMoved == !failApplication)
    #expect(attempted == (failApplication ? [url.path] : [url.path, cache.path]))
    #expect(result.failures.count == 1 && result.movedFiles.isEmpty)
    #expect(f.fm.fileExists(atPath: cache.path))
}

@Test(arguments: ["database", "container", "outside"])
func forgedRelatedCapabilitiesCannotGrantDeletion(kind: String) throws {
    let f = try Fixture()
    let url = try f.application("Applications/Example.app", id: "org.example.editor")
    let path = kind == "database" ? "Users/tester/Library/Application Support/org.example.editor/profile.sqlite" :
        kind == "container" ? "Users/tester/Library/Containers/org.example.editor/Data/data" : "Users/tester/Documents/keep"
    let protected = try f.file(path)
    let uninstaller = service(f)
    let plan = uninstaller.review(try InstalledApplication.read(at: url))
    let forgedFile = RelatedApplicationFile(url: protected, snapshot: try FileMetadata.read(protected).snapshot,
        recommendation: .recommended, reasonText: .init("Forged"))
    let forged = ApplicationRemovalPlan(application: plan.application, bundleSnapshot: plan.bundleSnapshot,
        files: [forgedFile], warnings: [], protectionText: nil, limited: false, cancelled: false)
    var calls = 0
    let result = uninstaller.uninstall(forged, selectedDataIDs: [protected.path], trash: { _ in calls += 1 })
    #expect(!result.applicationMoved && calls == 0)
    #expect(f.fm.fileExists(atPath: protected.path))
}

@Test func bundleSymlinksAreRecordedWithoutFollowingExternalTargets() throws {
    let f = try Fixture()
    let url = try f.application("Applications/Example.app", id: "org.example.editor")
    let outside = try f.file("External/large", bytes: 100_000_000)
    let link = url.appendingPathComponent("Contents/linked")
    try f.fm.createSymbolicLink(at: link, withDestinationURL: outside.deletingLastPathComponent())
    let snapshot = try ApplicationBundleSnapshot.capture(url)
    #expect(snapshot.bytes < 100_000_000)
    #expect(snapshot.entries["Contents/linked"] != nil && snapshot.entries["Contents/linked/large"] == nil)
    #expect(throws: (any Error).self) { try ApplicationBundleSnapshot.capture(url, maximumEntries: 2) }
    #expect(!service(f).review(try InstalledApplication.read(at: url), isCancelled: { true }).canRemoveApplication)
    #expect(f.fm.fileExists(atPath: outside.path))
}

import Foundation
import Testing
@testable import CleanMac
@testable import CleanMacCore

@MainActor @Test func checkingUpdatesPreservesScanStateAndDoesNotOpenAModal() async throws {
    let name = "CleanMacUpdates.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let updates = AppUpdates(defaults: defaults, currentVersion: "0.4.0", checker: { _ in nil })
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let app = AppModel(home: root, systemRoot: root, updates: updates,
                       diskSpaceReader: { _ in DiskSpace(total: 1_000, available: 640) })
    await app.refreshDisk()
    #expect(app.disk?.total == 1_000 && app.disk?.available == 640)
    app.selectedIDs = ["sample-selection"]
    app.query = "sample-query"
    app.recommendationFilter = .review
    await updates.check()
    #expect(app.selectedIDs == ["sample-selection"] && app.query == "sample-query")
    #expect(app.recommendationFilter == .review && !app.showUpdates && !app.hasScanned)
    #expect(app.phase == .idle)
}

private actor UpdateCalls {
    var count = 0
    func record() { count += 1 }
}

@MainActor @Test func automaticUpdateChecksRequireOptInAndUseDailyThrottle() async throws {
    let name = "CleanMacUpdates.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let calls = UpdateCalls()
    let model = AppUpdates(defaults: defaults, currentVersion: "0.4.0", checker: { _ in await calls.record(); return nil })
    let now = Date(timeIntervalSince1970: 1_000_000)
    #expect(!model.automaticallyChecks)
    await model.checkAutomatically(now: now)
    #expect(await calls.count == 0)
    model.automaticallyChecks = true
    await model.checkAutomatically(now: now)
    #expect(await calls.count == 1)
    #expect(model.state == .upToDate)
    await model.checkAutomatically(now: now.addingTimeInterval(86_399))
    #expect(await calls.count == 1)
    await model.checkAutomatically(now: now.addingTimeInterval(86_400))
    #expect(await calls.count == 2)
    let restored = AppUpdates(defaults: defaults, currentVersion: "0.4.0", checker: { _ in await calls.record(); return nil })
    #expect(restored.automaticallyChecks)
    await restored.checkAutomatically(now: now.addingTimeInterval(86_401))
    #expect(await calls.count == 2)
    restored.automaticallyChecks = false
    await restored.checkAutomatically(now: now.addingTimeInterval(200_000))
    #expect(await calls.count == 2)
}

@MainActor @Test func manualChecksShowUpdatesAndRecoverWithoutOptIn() async throws {
    let name = "CleanMacUpdates.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let release = ReleaseUpdate(version: try #require(ReleaseVersion("0.5.0")), url: URL(string: "https://github.com/vuluu2k/clean-mac/releases/tag/v0.5.0")!)
    let model = AppUpdates(defaults: defaults, currentVersion: "0.4.0", checker: { version in
        #expect(version == "0.4.0")
        return release
    })
    await model.check()
    #expect(model.state == .available(release))
    #expect(!model.automaticallyChecks)
    let offline = AppUpdates(defaults: defaults, currentVersion: "0.4.0", checker: { _ in throw URLError(.notConnectedToInternet) })
    await offline.check()
    #expect(offline.state == .failed)
    let development = AppUpdates(defaults: defaults, currentVersion: "development", checker: { _ in
        Issue.record("A development build must not make automatic requests")
        return nil
    })
    development.automaticallyChecks = true
    await development.checkAutomatically()
    #expect(development.state == .idle)
}

@MainActor @Test func concurrentUpdateChecksDoNotDuplicateRequests() async throws {
    let name = "CleanMacUpdates.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let calls = UpdateCalls()
    let model = AppUpdates(defaults: defaults, currentVersion: "0.4.0", checker: { _ in
        await calls.record()
        try await Task.sleep(for: .milliseconds(30))
        return nil
    })
    let first = Task { await model.check() }
    while model.state != .checking { await Task.yield() }
    await model.check()
    await first.value
    #expect(await calls.count == 1)
    #expect(model.state == .upToDate)
}

import CleanMacCore
import Foundation
import SwiftUI

@MainActor
final class AppUpdates: ObservableObject {
    enum State: Equatable { case idle, checking, upToDate, available(ReleaseUpdate), failed }
    private static let preferenceKey = "cleanMacAutomaticallyChecksForUpdates"
    private static let lastCheckKey = "cleanMacLastAutomaticUpdateCheck"
    @Published private(set) var state: State = .idle
    @Published var automaticallyChecks: Bool {
        didSet { defaults.set(automaticallyChecks, forKey: Self.preferenceKey) }
    }
    let currentVersion: String
    var canCheck: Bool { ReleaseVersion(currentVersion) != nil }
    private let defaults: UserDefaults
    private let checker: @Sendable (String) async throws -> ReleaseUpdate?

    init(defaults: UserDefaults = .standard, currentVersion: String? = nil,
         checker: @escaping @Sendable (String) async throws -> ReleaseUpdate? = { try await UpdateChecker().check(currentVersion: $0) }) {
        self.defaults = defaults
        self.currentVersion = currentVersion ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        self.checker = checker
        automaticallyChecks = defaults.bool(forKey: Self.preferenceKey)
    }

    func checkAutomatically(now: Date = Date()) async {
        guard automaticallyChecks, canCheck, state != .checking else { return }
        if let last = defaults.object(forKey: Self.lastCheckKey) as? Date, now.timeIntervalSince(last) < 86_400 { return }
        defaults.set(now, forKey: Self.lastCheckKey)
        await check()
    }

    func check() async {
        guard state != .checking else { return }
        state = .checking
        do {
            if let release = try await checker(currentVersion) { state = .available(release) }
            else { state = .upToDate }
        } catch is CancellationError { state = .idle }
        catch { state = .failed }
    }
}

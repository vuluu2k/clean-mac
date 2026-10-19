import CleanMacCore
import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppUpdates: ObservableObject {
    enum State: Equatable { case idle, checking, upToDate, available(ReleaseUpdate), failed, installing(ReleaseUpdate), installFailed(ReleaseUpdate), installed(ReleaseUpdate) }
    private static let preferenceKey = "cleanMacAutomaticallyChecksForUpdates"
    private static let lastCheckKey = "cleanMacLastAutomaticUpdateCheck"
    @Published private(set) var state: State = .idle
    @Published var automaticallyChecks: Bool {
        didSet { defaults.set(automaticallyChecks, forKey: Self.preferenceKey) }
    }
    let currentVersion: String
    var canCheck: Bool { ReleaseVersion(currentVersion) != nil }
    /// nil when the app is not in a writable Applications folder; the release link is the fallback.
    let installTarget: URL?
    private let defaults: UserDefaults
    private let checker: @Sendable (String) async throws -> ReleaseUpdate?
    private let installer: @Sendable (ReleaseUpdate, URL) async throws -> URL
    private let relaunch: @MainActor (URL) -> Void

    init(defaults: UserDefaults = .standard, currentVersion: String? = nil,
         installTarget: URL? = UpdateInstaller.installTarget(bundle: Bundle.main.bundleURL, home: FileManager.default.homeDirectoryForCurrentUser),
         checker: @escaping @Sendable (String) async throws -> ReleaseUpdate? = { try await UpdateChecker().check(currentVersion: $0) },
         installer: @escaping @Sendable (ReleaseUpdate, URL) async throws -> URL = { try await UpdateInstaller().install($0, replacing: $1) },
         relaunch: @escaping @MainActor (URL) -> Void = AppUpdates.relaunch) {
        self.defaults = defaults
        self.currentVersion = currentVersion ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        self.installTarget = installTarget
        self.checker = checker
        self.installer = installer
        self.relaunch = relaunch
        automaticallyChecks = defaults.bool(forKey: Self.preferenceKey)
    }

    func checkAutomatically(now: Date = Date()) async {
        guard automaticallyChecks, canCheck, !isWorking else { return }
        if let last = defaults.object(forKey: Self.lastCheckKey) as? Date, now.timeIntervalSince(last) < 86_400 { return }
        defaults.set(now, forKey: Self.lastCheckKey)
        await check()
    }

    var release: ReleaseUpdate? {
        switch state { case .available(let r), .installing(let r), .installFailed(let r), .installed(let r): r; default: nil }
    }

    var isWorking: Bool {
        switch state { case .checking, .installing: true; default: false }
    }

    func check() async {
        guard !isWorking else { return }
        state = .checking
        do {
            if let release = try await checker(currentVersion) { state = .available(release) }
            else { state = .upToDate }
        } catch is CancellationError { state = .idle }
        catch { state = .failed }
    }

    func install(_ release: ReleaseUpdate) async {
        guard let target = installTarget, !isWorking, state != .installed(release) else { return }
        state = .installing(release)
        do {
            let app = try await installer(release, target)
            // Shown only if the relaunch below does not quit this instance.
            state = .installed(release)
            relaunch(app)
        }
        catch { state = .installFailed(release) }
    }

    static func relaunch(_ app: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: app, configuration: configuration) { _, error in
            guard error == nil else { return }
            Task { @MainActor in
                // A window with an open sheet refuses to terminate, so close sheets first.
                for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
                NSApp.terminate(nil)
            }
        }
    }
}

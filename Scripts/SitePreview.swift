// Capture production SwiftUI views using only owned sample roots and injected services.
import AppKit
@testable import CleanMacCore
import SwiftUI

@MainActor final class PreviewDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var model: AppModel!
    private let mode = CommandLine.arguments[1]
    private let output = CommandLine.arguments[2]

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let fm = FileManager.default
            let root = URL(fileURLWithPath: "/tmp/clean-mac-preview-\(UUID().uuidString.prefix(8))").resolvingSymlinksInPath()
            try fm.createDirectory(at: root, withIntermediateDirectories: false)
            func file(_ path: String, bytes: UInt64 = 64, old: Bool = false) throws -> URL {
                let url = root.appendingPathComponent(path)
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data([65]).write(to: url)
                let handle = try FileHandle(forWritingTo: url)
                try handle.truncate(atOffset: bytes)
                try handle.close()
                if old { try fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -45 * 86_400)], ofItemAtPath: url.path) }
                return url
            }
            for (path, id, name) in [("Applications/Studio.app", "com.example.studio", "Sample Studio"),
                                     ("Applications/Notes.app", "org.sample.notes", "Sample Notes"),
                                     ("System/Applications/System.app", "com.apple.sample", "System App")] {
                let info = try file(path + "/Contents/Info.plist")
                try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": id, "CFBundleName": name], format: .xml, options: 0).write(to: info)
                _ = try file(path + "/Contents/MacOS/sample", bytes: 38_000_000)
            }
            _ = try file("Users/demo/Library/Caches/com.example.studio/preview-cache.bin", bytes: 1_280_000_000, old: true)
            _ = try file("Users/demo/Library/Caches/org.sample.browser/session-cache.bin", bytes: 620_000_000, old: true)
            _ = try file("Users/demo/Library/Logs/com.example.studio/diagnostics.log", bytes: 180_000_000, old: true)
            _ = try file("Users/demo/Library/Developer/Xcode/DerivedData/SampleBuild/build.o", bytes: 2_400_000_000, old: true)
            _ = try file("Users/demo/Downloads/Studio-Installer.dmg", bytes: 1_600_000_000, old: true)
            _ = try file("Users/demo/Downloads/Video-archive.zip", bytes: 3_200_000_000)
            _ = try file("Users/demo/Library/Preferences/com.example.studio.plist")
            _ = try file("Users/demo/Library/Application Support/com.example.studio/presets.json")
            _ = try file("Users/demo/Library/Application Support/com.example.studio/library.sqlite", bytes: 240_000_000)
            _ = try file("Users/demo/Library/Containers/com.example.studio/Data/settings")
            _ = try file("Library/Preferences/com.example.studio.plist")
            _ = try file("Library/Sample/read-only.bin", bytes: 120_000_000)
            (mode.hasSuffix("-vi") ? AppLanguage.vietnamese : .english).save()
            let updates = AppUpdates(currentVersion: "0.4.0", checker: { _ in
                ReleaseUpdate(version: ReleaseVersion("0.5.0")!, url: URL(string: "https://github.com/vuluu2k/clean-mac/releases/tag/v0.5.0")!)
            })
            precondition(!updates.automaticallyChecks)
            model = AppModel(home: root.appendingPathComponent("Users/demo"), systemRoot: root, updates: updates,
                diskSpaceReader: { _ in DiskSpace(total: 1_000_000_000_000, available: 640_000_000_000) },
                isRegistered: { _ in false }, isApplicationRunning: { _ in false }, registeredApplicationURL: { _ in nil },
                trashOperation: { _ in preconditionFailure("Site preview must never invoke Trash") })
            NSApp.appearance = NSAppearance(named: .darkAqua)
            window = NSWindow(contentRect: NSRect(x: 40, y: 40, width: 1220, height: 1040),
                styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "clean-mac"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.contentView = NSHostingView(rootView: Dashboard(model: model))
            window.level = .floating
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            Task { await prepareAndCapture() }
        } catch { fail(error) }
    }

    private func prepareAndCapture() async {
        do {
            try await Task.sleep(for: .milliseconds(500))
            precondition(L10n.bundle(for: .english).bundleURL.path.hasPrefix(Bundle.main.resourceURL!.path))
            if mode.hasPrefix("storage") {
                model.setScanMode(.deep)
                model.scan()
                while model.busy { try await Task.sleep(for: .milliseconds(10)) }
                precondition(model.report.items.count >= 7 && model.selectedIDs.isEmpty)
            } else if mode.hasPrefix("updates") {
                await model.updates.check()
                model.showUpdates = true
            } else {
                model.scanApplications()
                while model.busy { try await Task.sleep(for: .milliseconds(10)) }
                let app = model.filteredApplications.first { $0.identifier == "com.example.studio" }!
                model.reviewApplication(app)
                while model.busy { try await Task.sleep(for: .milliseconds(10)) }
                precondition(model.selectedRelatedIDs.isEmpty)
                if mode.hasPrefix("confirm") {
                    try await Task.sleep(for: .milliseconds(600))
                    model.selectRecommendedApplicationFiles()
                    model.prepareApplicationRemoval()
                    precondition(model.applicationConfirmation != nil)
                }
            }
            try await Task.sleep(for: .seconds(1))
            let frame = window.frame
            let screenHeight = NSScreen.screens[0].frame.height
            let rect = "\(Int(frame.minX)),\(Int(screenHeight - frame.maxY)),\(Int(frame.width)),\(Int(frame.height))"
            let capture = Process()
            capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            capture.arguments = ["-x", "-R", rect, output]
            try capture.run()
            capture.waitUntilExit()
            precondition(capture.terminationStatus == 0)
            print("CAPTURED \(mode) \(Int(frame.width))x\(Int(frame.height)) sample roots only, fixed disk, fake updates, blocked Trash")
            NSApp.terminate(nil)
        } catch { fail(error) }
    }

    private func fail(_ error: Error) -> Never {
        FileHandle.standardError.write(Data("Preview failed: \(error)\n".utf8))
        exit(1)
    }
}

@main struct SitePreview {
    @MainActor static func main() {
        precondition(CommandLine.arguments.count == 3)
        let app = NSApplication.shared
        let delegate = PreviewDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

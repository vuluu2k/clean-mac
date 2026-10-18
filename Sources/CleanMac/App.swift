import AppKit
import CleanMacCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct CleanMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("clean-mac") { Dashboard(model: model) }
            .defaultSize(width: 1220, height: 850)
            .windowStyle(.hiddenTitleBar)
            .commands {
                CommandGroup(after: .appInfo) {
                    Button(L10n.text("Kiểm tra cập nhật…")) { model.showUpdates = true }
                        .disabled(model.hasOpenReview)
                }
                CommandGroup(replacing: .newItem) {
                    Button(L10n.text("Quét thông minh"), action: model.scan)
                        .keyboardShortcut("r").disabled(model.busy || model.hasOpenReview)
                }
            }
    }
}

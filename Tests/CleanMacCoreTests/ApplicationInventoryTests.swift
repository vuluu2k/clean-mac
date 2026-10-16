import Foundation
import Testing
@testable import CleanMacCore

extension Fixture {
    @discardableResult
    func application(_ path: String, id: String) throws -> URL {
        let info = try file(path + "/Contents/Info.plist")
        let data = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": id], format: .xml, options: 0)
        try data.write(to: info)
        return info.deletingLastPathComponent().deletingLastPathComponent()
    }
}

@Test func inventoryReadsBundleIDsAndProtectsRelatedAppFamilies() throws {
    let f = try Fixture()
    let app = try f.application("Applications/Live.app", id: "com.active.editor")
    let nested = try f.application("Applications/Tools/Other.app", id: "org.tools.utility")
    let inventory = ApplicationInventory.scan(roots: [f.home.appendingPathComponent("Applications")])
    #expect(inventory.identifiers == ["com.active.editor", "org.tools.utility"])
    #expect(inventory.complete)
    #expect(Set(inventory.applications.map(\.url)) == [app, nested])
    #expect(inventory.applications.first { $0.url == app }?.name == "Live")
    #expect(inventory.mayOwn("com.active.editor.helper"))
    #expect(inventory.mayOwn("com.active.removed"))
    #expect(!inventory.mayOwn("com.retired.utility"))
    #expect(f.fm.fileExists(atPath: app.path) && f.fm.fileExists(atPath: nested.path))
}

@Test func invalidOrSymlinkedAppsMakeInventoryIncomplete() throws {
    let f = try Fixture()
    let app = try f.application("Elsewhere/Hidden.app", id: "com.hidden.tool")
    try f.fm.createDirectory(at: f.home.appendingPathComponent("Applications"), withIntermediateDirectories: true)
    try f.fm.createSymbolicLink(at: f.home.appendingPathComponent("Applications/Link.app"), withDestinationURL: app)
    _ = try f.file("Applications/Invalid.app/Contents/Info.plist")
    let inventory = ApplicationInventory.scan(roots: [f.home.appendingPathComponent("Applications")])
    #expect(!inventory.complete)
    #expect(inventory.identifiers.isEmpty)
    #expect(!inventory.warnings.isEmpty)
    let cancelled = ApplicationInventory.scan(roots: [f.home], isCancelled: { true })
    #expect(!cancelled.complete)
}

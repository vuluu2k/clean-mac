import Foundation
import Testing
@testable import CleanMacCore

@Test func recommendationsSeparateRegenerableDataFromUncertainAndLockedFiles() throws {
    let f = try Fixture()
    let file = try f.file("fixture")
    let snapshot = try FileMetadata.read(file).snapshot
    for category in [CleanupCategory.caches, .logs, .developer] {
        #expect(ScanItem(url: file, category: category, snapshot: snapshot).recommendation == .recommended)
    }
    for category in [CleanupCategory.installers, .largeFiles, .appLeftovers] {
        #expect(ScanItem(url: file, category: category, snapshot: snapshot).recommendation == .review)
    }
    #expect(ScanItem(url: file, category: .systemFiles, snapshot: snapshot).recommendation == .keep)
    #expect(ScanItem(url: file, category: .caches, snapshot: snapshot, isReadOnly: true).recommendation == .keep)
}

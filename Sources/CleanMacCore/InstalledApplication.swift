import Foundation

public struct InstalledApplication: Identifiable, Equatable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let identifier: String
    public let name: String
    public let snapshot: FileSnapshot

    static func read(at url: URL) throws -> Self {
        let contents = url.appendingPathComponent("Contents")
        let info = contents.appendingPathComponent("Info.plist")
        let appMetadata = try FileMetadata.read(url)
        let contentsMetadata = try FileMetadata.read(contents)
        let infoMetadata = try FileMetadata.read(info)
        guard appMetadata.isDirectory, !appMetadata.isSymbolicLink, !appMetadata.isDataless,
              contentsMetadata.isDirectory, !contentsMetadata.isSymbolicLink, !contentsMetadata.isDataless,
              infoMetadata.isRegular, infoMetadata.linkCount == 1, !infoMetadata.isDataless,
              infoMetadata.snapshot.size > 0, infoMetadata.snapshot.size <= 1_048_576 else { throw SafetyError.unsafePath }
        let handle = try FileHandle(forReadingFrom: info)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 1_048_577) ?? Data()
        guard data.count <= 1_048_576, try FileMetadata.read(info).snapshot == infoMetadata.snapshot,
              try FileMetadata.read(url).snapshot == appMetadata.snapshot else { throw SafetyError.changedFile }
        let dictionary = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        guard let identifier = dictionary?["CFBundleIdentifier"] as? String,
              !identifier.isEmpty, identifier.count <= 255 else { throw SafetyError.notEligible }
        let rawName = dictionary?["CFBundleDisplayName"] as? String ?? dictionary?["CFBundleName"] as? String ?? url.deletingPathExtension().lastPathComponent
        return Self(url: url, identifier: identifier, name: String(rawName.prefix(200)), snapshot: appMetadata.snapshot)
    }
}

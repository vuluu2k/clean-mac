import AppKit
import Foundation

public struct ApplicationInventory: Sendable {
    public private(set) var identifiers = Set<String>()
    public private(set) var applications: [InstalledApplication] = []
    public private(set) var complete = true
    public private(set) var warnings: [ScanWarning] = []

    public static func defaultRoots(home: URL, systemRoot: URL) -> [URL] {
        ["Applications", "System/Applications", "System/Library/CoreServices"].map {
            systemRoot.appendingPathComponent($0)
        } + [home.appendingPathComponent("Applications")]
    }

    public static func isRegistered(_ identifier: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) != nil
    }

    public func mayOwn(_ identifier: String, excluding application: URL? = nil) -> Bool {
        let candidates = application.map { excluded in Set(applications.filter { $0.id != excluded.path }.map { $0.identifier.lowercased() }) } ?? identifiers
        let target = identifier.lowercased()
        let vendor = target.split(separator: ".").prefix(2).joined(separator: ".")
        return candidates.contains { installed in
            let installed = installed.lowercased()
            return installed == target || installed.hasPrefix(target + ".") || target.hasPrefix(installed + ".") ||
                installed.split(separator: ".").prefix(2).joined(separator: ".") == vendor
        }
    }

    mutating func noteFailure(_ url: URL, _ error: Error) {
        complete = false
        if warnings.count < 100 { warnings.append(ScanWarning(path: url.path, messageText: .init(error: error))) }
    }

    mutating func recordApplication(at url: URL) {
        do {
            let application = try InstalledApplication.read(at: url)
            identifiers.insert(application.identifier.lowercased())
            if !applications.contains(where: { $0.id == application.id }) { applications.append(application) }
        } catch { noteFailure(url, error) }
    }

    public static func scan(roots: [URL], isCancelled: @Sendable () -> Bool = { false }) -> Self {
        var inventory = Self()
        for root in roots {
            if isCancelled() { inventory.complete = false; break }
            do {
                let metadata = try FileMetadata.read(root)
                guard metadata.isDirectory, !metadata.isSymbolicLink, !metadata.isDataless else { throw SafetyError.unsafePath }
            } catch {
                let error = error as NSError
                if error.domain != NSPOSIXErrorDomain || error.code != Int(ENOENT) { inventory.noteFailure(root, error) }
                continue
            }
            guard let enumerator = FileManager().enumerator(
                at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { url, error in inventory.noteFailure(url, error); return true }
            ) else { inventory.noteFailure(root, CocoaError(.fileReadUnknown)); continue }
            while let entry = enumerator.nextObject() as? URL {
                let url = entry.pathComponents.suffix(enumerator.level).reduce(root) { $0.appendingPathComponent($1) }
                if isCancelled() { inventory.complete = false; break }
                do {
                    let metadata = try FileMetadata.read(url)
                    if metadata.isSymbolicLink || metadata.isDataless {
                        enumerator.skipDescendants()
                        if url.pathExtension.lowercased() == "app" { inventory.noteFailure(url, SafetyError.unsafePath) }
                        continue
                    }
                    if metadata.isDirectory, url.pathExtension.lowercased() == "app" {
                        inventory.recordApplication(at: url)
                        enumerator.skipDescendants()
                    }
                } catch { inventory.noteFailure(url, error) }
            }
        }
        return inventory
    }
}

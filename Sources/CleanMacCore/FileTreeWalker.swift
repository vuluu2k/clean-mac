import Foundation

struct FileTreeWalker {
    struct Status {
        var files = 0
        var entries = 0
        var directories = 0
        var limited = false
        var cancelled = false
    }

    static func walk(
        at root: URL, includeHidden: Bool = false, includePackages: Bool = false,
        maximumEntries: Int? = nil,
        isCancelled: @Sendable () -> Bool,
        visit: (URL, FileMetadata) -> Bool,
        onError: (URL, Error) -> Void
    ) -> Status {
        var status = Status()
        var directories = [root]
        var seenDirectories = Set<String>()
        let fm = FileManager()
        while let directory = directories.popLast() {
            if isCancelled() { status.cancelled = true; break }
            do {
                let metadata = try FileMetadata.read(directory)
                guard metadata.isDirectory, !metadata.isSymbolicLink, !metadata.isDataless else { throw SafetyError.unsafePath }
                let key = "\(metadata.snapshot.device):\(metadata.snapshot.inode)"
                guard seenDirectories.insert(key).inserted else { continue }
                status.directories += 1
                // Relative names preserve the validated root; URL enumeration can rewrite /var to /private/var.
                for name in try fm.contentsOfDirectory(atPath: directory.path) {
                    if isCancelled() { status.cancelled = true; return status }
                    if let maximumEntries, status.entries >= maximumEntries { status.limited = true; return status }
                    status.entries += 1
                    if !includeHidden && name.hasPrefix(".") { continue }
                    let url = directory.appendingPathComponent(name)
                    do {
                        let info = try FileMetadata.read(url)
                        guard !info.isSymbolicLink, !info.isDataless else { continue }
                        let values = try url.resourceValues(forKeys: [.isAliasFileKey, .isUbiquitousItemKey, .isPackageKey])
                        guard values.isAliasFile != true, values.isUbiquitousItem != true else { continue }
                        if !includePackages && (values.isPackage == true || ScanPolicy.packageExtensions.contains(url.pathExtension.lowercased())) { continue }
                        if info.isRegular { status.files += 1 }
                        if visit(url, info), info.isDirectory { directories.append(url) }
                    } catch { onError(url, error) }
                }
            } catch { onError(directory, error) }
        }
        return status
    }
}

import Foundation

extension ApplicationBundleSnapshot {
    static func capture(_ root: URL, maximumEntries: Int = 200_000,
                        isCancelled: @Sendable () -> Bool = { false }) throws -> Self {
        let original = try FileMetadata.read(root)
        guard original.isDirectory, !original.isSymbolicLink, !original.isDataless else { throw SafetyError.unsafePath }
        var entries = ["": original.snapshot]
        var directories = [root]
        var seen = Set<String>()
        var bytes: Int64 = 0
        while let directory = directories.popLast() {
            if isCancelled() { throw SafetyError.cancelled }
            let metadata = try FileMetadata.read(directory)
            guard metadata.isDirectory, !metadata.isSymbolicLink, !metadata.isDataless,
                  seen.insert("\(metadata.snapshot.device):\(metadata.snapshot.inode)").inserted else { throw SafetyError.unsafePath }
            for name in try FileManager().contentsOfDirectory(atPath: directory.path) {
                if isCancelled() { throw SafetyError.cancelled }
                guard entries.count < maximumEntries else { throw SafetyError.incompleteInspection }
                let url = directory.appendingPathComponent(name)
                let info = try FileMetadata.read(url)
                guard !info.isDataless, info.snapshot.device == original.snapshot.device else { throw SafetyError.unsafePath }
                entries[String(url.path.dropFirst(root.path.count + 1))] = info.snapshot
                if info.isDirectory { directories.append(url) }
                else if info.isRegular { bytes += info.snapshot.size }
                else if !info.isSymbolicLink { throw SafetyError.unsafePath }
                // Bundle symlinks are recorded, never followed; native Trash moves the bundle as a unit.
            }
        }
        guard try FileMetadata.read(root).snapshot == original.snapshot else { throw SafetyError.changedFile }
        return Self(entries: entries, bytes: bytes)
    }
}

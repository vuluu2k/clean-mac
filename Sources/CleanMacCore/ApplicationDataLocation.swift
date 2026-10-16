import Foundation

struct ApplicationDataLocation {
    let root: URL
    let userOwned: Bool
    let cleanable: Bool
    let plist: Bool
    let savedState: Bool

    static func defaults(home: URL, systemRoot: URL) -> [Self] {
        let user = ["Caches", "Logs", "Application Support", "Preferences", "Saved Application State", "Containers", "LaunchAgents"]
        let system = ["Caches", "Logs", "Application Support", "Preferences", "LaunchAgents", "LaunchDaemons"]
        return [(home.appendingPathComponent("Library"), user, true),
                (systemRoot.appendingPathComponent("Library"), system, false)].flatMap { base, names, userOwned in
            names.map { name in
                Self(root: base.appendingPathComponent(name), userOwned: userOwned,
                    cleanable: userOwned && name != "Containers" && name != "LaunchAgents",
                    plist: ["Preferences", "LaunchAgents", "LaunchDaemons"].contains(name), savedState: name == "Saved Application State")
            }
        }
    }

    func owner(of url: URL) -> String? {
        guard ScanPolicy.contains(root, url) else { return nil }
        let parts = url.path.dropFirst(root.path.count + 1).split(separator: "/").map(String.init)
        guard var identifier = parts.first, !identifier.hasPrefix(".") else { return nil }
        if plist {
            guard parts.count == 1, identifier.hasSuffix(".plist") else { return nil }
            identifier = String(identifier.dropLast(6))
        } else if savedState {
            guard identifier.hasSuffix(".savedState") else { return nil }
            identifier = String(identifier.dropLast(11))
        }
        let components = identifier.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count >= 3, identifier.count <= 255,
              components.allSatisfy({ !$0.isEmpty && $0.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-").contains($0) } }),
              !identifier.lowercased().hasPrefix("com.apple."), !identifier.lowercased().hasPrefix("group.") else { return nil }
        return identifier
    }
}

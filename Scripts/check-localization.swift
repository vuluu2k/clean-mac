import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let fm = FileManager.default
let output = root.appendingPathComponent(".build/localization-check-\(UUID())")
let pattern = #"%(?:\d+\$)?(?:\d+)?(?:\.\d+)?(?:ll|l|hh|h|z)?[@diuoxXfFeEgGcCsSp]"#
let expression = try NSRegularExpression(pattern: pattern)
func signature(_ text: String) -> [String] {
    let text = text.replacingOccurrences(of: "%%", with: "")
    return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { (text as NSString).substring(with: $0.range) }
}
precondition(signature("100% LOCAL · %lld files · %@") == ["%lld", "%@"])
precondition(signature("%% %@ %.2f") == ["%@", "%.2f"])

func table(_ language: String, _ name: String = "Localizable") throws -> [String: String] {
    let file = root.appendingPathComponent("Sources/CleanMacCore/Resources/\(language).lproj/\(name).strings")
    guard let result = try PropertyListSerialization.propertyList(from: Data(contentsOf: file), format: nil) as? [String: String] else {
        throw CocoaError(.propertyListReadCorrupt)
    }
    return result
}

do {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", "build", "-Xswiftc", "-emit-localized-strings", "-Xswiftc", "-emit-localized-strings-path", "-Xswiftc", output.path]
    process.currentDirectoryURL = root
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let log = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        FileHandle.standardError.write(log)
        exit(1)
    }
    var keys = Set<String>()
    for file in try fm.contentsOfDirectory(at: output, includingPropertiesForKeys: nil) where file.pathExtension == "stringsdata" {
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        let tables = json?["tables"] as? [String: [[String: Any]]]
        for entry in tables?["Localizable"] ?? [] { if let key = entry["key"] as? String { keys.insert(key) } }
    }
    guard !keys.isEmpty else { throw CocoaError(.fileReadUnknown) }
    let english = try table("en")
    let vietnamese = try table("vi")
    var issues: [String] = []
    for key in keys.sorted() {
        guard let translated = english[key] else { issues.append("Missing English key: \(key)"); continue }
        if signature(key) != signature(translated) { issues.append("Placeholder mismatch: \(key)") }
        if !key.isEmpty && translated.isEmpty { issues.append("Empty English value: \(key)") }
        if let translated = vietnamese[key], signature(key) != signature(translated) { issues.append("Vietnamese placeholder mismatch: \(key)") }
    }
    let enPrivacy = try table("en", "InfoPlist")
    let viPrivacy = try table("vi", "InfoPlist")
    if Set(enPrivacy.keys) != Set(viPrivacy.keys) || enPrivacy.count != 3 { issues.append("Privacy descriptions must match in both languages") }
    if !issues.isEmpty {
        FileHandle.standardError.write(Data((issues.prefix(20).joined(separator: "\n") + "\nLocalization issues: \(issues.count)\n").utf8))
        exit(1)
    }
    print("Localization check passed: \(keys.count) extracted keys, English coverage complete, placeholders match, 3 bilingual privacy descriptions. Vietnamese source text is the fallback.")
} catch {
    FileHandle.standardError.write(Data("Localization check failed: \(error)\n".utf8))
    exit(1)
}

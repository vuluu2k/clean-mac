import Foundation
import Testing
@testable import CleanMacCore

@Test func localizedLabelsAndInterpolationsSupportBothLanguages() {
    #expect(L10n.text("Khuyên dọn", language: .vietnamese) == "Khuyên dọn")
    #expect(L10n.text("Khuyên dọn", language: .english) == "Recommended")
    #expect(L10n.text("\(3) tệp · \("4 MB")", language: .english) == "Files: 3 · 4 MB")
    let message = LocalizedText("\(3) tệp · \("4 MB")")
    #expect(message.localized(language: .vietnamese) == "3 tệp · 4 MB")
    #expect(message.localized(language: .english) == "Files: 3 · 4 MB")
    #expect(message == LocalizedText("\(3) tệp · \("4 MB")"))
    #expect(L10n.text("100% CỤC BỘ", language: .english) == "100% LOCAL")
    let name = "資料 %@ %lld.app"
    #expect(L10n.text("Xác nhận gỡ \(name)", language: .english) == "Confirm uninstalling \(name)")
}

@Test func capturedSafetyMessagesTranslateWithoutChangingWarningIdentity() {
    let message = SafetyError.changedFile.localizedText
    let warning = ScanWarning(path: "/fixture/file", messageText: message)
    let identity = warning.id
    #expect(message.localized(language: .english) == "The file changed after the scan. Scan again.")
    #expect(message.localized(language: .vietnamese) == "Tệp đã thay đổi sau lần quét. Hãy quét lại.")
    #expect(warning.id == identity)
    let native = LocalizedText(error: CocoaError(.fileReadNoPermission))
    #expect(native.localized(language: .english) == native.localized(language: .vietnamese))
}

@Test func languagePreferencePersistsWithoutChangingGlobalDefaults() throws {
    let name = "CleanMacLocalizationTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    #expect(AppLanguage.read(from: defaults) == .vietnamese)
    AppLanguage.english.save(to: defaults)
    #expect(AppLanguage.read(from: defaults) == .english)
    defaults.set("unsupported", forKey: AppLanguage.preferenceKey)
    #expect(AppLanguage.read(from: defaults) == .vietnamese)
}

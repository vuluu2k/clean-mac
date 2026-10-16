import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case vietnamese = "vi", english = "en"
    public static let preferenceKey = "cleanMacLanguage"
    public var id: Self { self }
    public var title: String { self == .vietnamese ? "Tiếng Việt" : "English" }
    public var locale: Locale { Locale(identifier: rawValue) }
    public static var current: Self { read() }
    public static func read(from defaults: UserDefaults = .standard) -> Self {
        Self(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? .vietnamese
    }
    public func save(to defaults: UserDefaults = .standard) { defaults.set(rawValue, forKey: Self.preferenceKey) }
}

public enum L10n {
    private static let resources: Bundle = Bundle.main.url(forResource: "clean-mac_CleanMacCore", withExtension: "bundle").flatMap(Bundle.init(url:)) ?? .module
    private static let bundles: [AppLanguage: Bundle] = Dictionary(uniqueKeysWithValues: AppLanguage.allCases.compactMap { language in
        resources.url(forResource: language.rawValue, withExtension: "lproj").flatMap(Bundle.init(url:)).map { (language, $0) }
    })
    public static func bundle(for language: AppLanguage) -> Bundle { bundles[language] ?? resources }
    public static func text(_ value: String.LocalizationValue, language: AppLanguage = .current) -> String {
        String(localized: value, bundle: bundle(for: language), locale: language.locale)
    }
}

public struct LocalizedText: Equatable, Sendable {
    private let value: String.LocalizationValue
    let source: String
    public var isEmpty: Bool { source.isEmpty }
    public init(_ value: String.LocalizationValue) {
        self.value = value
        source = L10n.text(value, language: .vietnamese)
    }
    public init(error: Error) {
        self = (error as? SafetyError)?.localizedText ?? Self(String.LocalizationValue(stringLiteral: error.localizedDescription))
    }
    public func localized(language: AppLanguage = .current) -> String { L10n.text(value, language: language) }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.source == rhs.source }
}

import Foundation

/// Localized UI strings from `Localizable.xcstrings` in the module bundle.
enum BookL10n {
    private static let appLanguageDefaultsKey = "aiBook.appLanguage"

    static var currentLanguage: BookAppLanguage {
        BookAppLanguage.migrated(from: UserDefaults.standard.string(forKey: appLanguageDefaultsKey))
    }

    static var activeLocale: Locale {
        Locale(identifier: languageCode(for: currentLanguage))
    }

    static func string(_ key: String) -> String {
        BookL10nCatalog.string(forKey: key, language: currentLanguage)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let template = string(key)
        return String(format: template, locale: activeLocale, arguments: arguments)
    }

    private static func languageCode(for language: BookAppLanguage) -> String {
        switch language {
        case .system:
            let id = Locale.current.identifier.lowercased()
            if id.hasPrefix("zh") { return "zh-Hans" }
            if id.hasPrefix("ja") { return "ja" }
            if id.hasPrefix("de") { return "de" }
            if id.hasPrefix("fr") { return "fr" }
            if id.hasPrefix("it") { return "it" }
            if id.hasPrefix("el") { return "el" }
            if id == "la" || id.hasPrefix("la_") { return "la" }
            return "en"
        case .zhHans: return "zh-Hans"
        case .en: return "en"
        case .ja: return "ja"
        case .de: return "de"
        case .fr: return "fr"
        case .it: return "it"
        case .la: return "la"
        case .el: return "el"
        }
    }
}

import Foundation

enum TranslationTargetLanguage: String, CaseIterable, Identifiable, Codable {
    case followAppLanguage
    case zhHans = "zh-Hans"
    case en
    case ja
    case de
    case fr
    case it
    case la
    case el

    var id: String { rawValue }

    static func migrated(from stored: String?) -> TranslationTargetLanguage {
        guard let stored, !stored.isEmpty else { return .followAppLanguage }
        return TranslationTargetLanguage(rawValue: stored) ?? .followAppLanguage
    }

    func resolved(
        appLanguage: BookAppLanguage,
        systemLocaleIdentifier: String = Locale.current.identifier
    ) -> TranslationTargetLanguage {
        guard self == .followAppLanguage else { return self }
        switch appLanguage {
        case .system:
            return Self.from(localeIdentifier: systemLocaleIdentifier)
        case .zhHans:
            return .zhHans
        case .en:
            return .en
        case .ja:
            return .ja
        case .de:
            return .de
        case .fr:
            return .fr
        case .it:
            return .it
        case .la:
            return .la
        case .el:
            return .el
        }
    }

    var localizedName: String {
        BookL10n.string(localizationKey)
    }

    var bcp47Identifier: String {
        precondition(self != .followAppLanguage)
        return rawValue
    }

    var promptLanguageName: String {
        switch self {
        case .followAppLanguage:
            return "Follow application language"
        case .zhHans:
            return "Modern Simplified Chinese"
        case .en:
            return "English"
        case .ja:
            return "Japanese"
        case .de:
            return "German"
        case .fr:
            return "French"
        case .it:
            return "Italian"
        case .la:
            return "Latin"
        case .el:
            return "Greek"
        }
    }

    private var localizationKey: String {
        switch self {
        case .followAppLanguage:
            return "translation.target.followApp"
        case .zhHans:
            return "language.zhHans"
        case .en:
            return "language.en"
        case .ja:
            return "language.ja"
        case .de:
            return "language.de"
        case .fr:
            return "language.fr"
        case .it:
            return "language.it"
        case .la:
            return "language.la"
        case .el:
            return "language.el"
        }
    }

    private static func from(localeIdentifier: String) -> TranslationTargetLanguage {
        let identifier = localeIdentifier.lowercased()
        if identifier.hasPrefix("zh") { return .zhHans }
        if identifier.hasPrefix("ja") { return .ja }
        if identifier.hasPrefix("de") { return .de }
        if identifier.hasPrefix("fr") { return .fr }
        if identifier.hasPrefix("it") { return .it }
        if identifier.hasPrefix("el") { return .el }
        if identifier == "la" || identifier.hasPrefix("la_") || identifier.hasPrefix("la-") {
            return .la
        }
        return .en
    }
}

enum TranslationTargetLanguageStore {
    static let key = "aiBook.translationTargetLanguage"

    static func load(
        from defaults: UserDefaults = .standard
    ) -> TranslationTargetLanguage {
        TranslationTargetLanguage.migrated(
            from: defaults.string(forKey: key)
        )
    }

    static func save(
        _ language: TranslationTargetLanguage,
        to defaults: UserDefaults = .standard
    ) {
        defaults.set(language.rawValue, forKey: key)
    }
}

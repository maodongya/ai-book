import Foundation

/// App UI language; `system` follows macOS locale.
enum BookAppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case zhHans = "zh-Hans"
    case en
    case ja
    case de
    case fr
    case it
    case la
    case el

    var id: String { rawValue }

    /// BCP-47 code for String Catalog, or `nil` for system default.
    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        default: return rawValue
        }
    }

    var locale: Locale? {
        guard let localeIdentifier else { return nil }
        return Locale(identifier: localeIdentifier)
    }

    /// Label in the language menu (native endonym).
    var nativeDisplayName: String {
        switch self {
        case .system: return "System"
        case .zhHans: return "简体中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .it: return "Italiano"
        case .la: return "Latina"
        case .el: return "Ελληνικά"
        }
    }

    var pickerLocalizationKey: String {
        switch self {
        case .system: return "language.system"
        case .zhHans: return "language.zhHans"
        case .en: return "language.en"
        case .ja: return "language.ja"
        case .de: return "language.de"
        case .fr: return "language.fr"
        case .it: return "language.it"
        case .la: return "language.la"
        case .el: return "language.el"
        }
    }

    static func migrated(from stored: String?) -> BookAppLanguage {
        guard let stored, !stored.isEmpty else { return .system }
        return BookAppLanguage(rawValue: stored) ?? .system
    }
}

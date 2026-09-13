import Foundation

/// 应用界面语言。`system` 跟随 macOS 地区，使用时再解析，不在用户点选时写成具体语言。
enum BookAppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case zhHans = "zh-Hans" // 目录与落盘都用 BCP-47，不用 zh
    case en
    case ja
    case de
    case fr
    case it
    case la
    case el

    /// Picker / ForEach 的稳定 id，等于 rawValue。
    var id: String { rawValue } // 和 Codable 落盘同一套，禁止另造数字 id

    /// 给 String Catalog 的 BCP-47；`.system` 为 nil，表示跟系统默认。
    var localeIdentifier: String? {
        switch self {
        case .system: return nil // 调用方必须再 resolved，不能把 nil 当 zh
        default: return rawValue // 显式语言的 rawValue 已是 BCP-47
        }
    }

    /// 显式语言对应的 Locale；system 为 nil，避免误以为已解析。
    var locale: Locale? {
        guard let localeIdentifier else { return nil } // system 在使用点解析
        return Locale(identifier: localeIdentifier) // 用产品码建 Locale，不是系统 Locale
    }

    /// 语言菜单里的自称（各语言 endonym），不走目录，避免切到未译语言时菜单空白。
    var nativeDisplayName: String {
        switch self {
        case .system: return "System" // 系统项用英文 System，各语言菜单都认
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

    /// 设置页 Picker 用的目录 key，和 nativeDisplayName 分开，便于「跟随系统」本地化。
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

    /// 读盘迁移：空值、缺省、乱值都变成 `.system`，读者从名字就能知道会回退。
    static func migrated(from stored: String?) -> BookAppLanguage {
        guard let stored, !stored.isEmpty else { return .system } // 从未写过或清空，跟随系统
        return BookAppLanguage(rawValue: stored) ?? .system // 不认识的旧码不当崩溃，当跟随系统
    }
}

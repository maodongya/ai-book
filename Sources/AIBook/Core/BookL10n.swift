import Foundation

/// 界面文案入口：从模块包里的 `Localizable.xcstrings` 取字符串。不负责翻译业务正文。
enum BookL10n {
    /// UserDefaults 里界面语言的键，和 AppSettings 必须共用这一处字面量。
    private static let appLanguageDefaultsKey = "aiBook.appLanguage"

    /// 当前界面语言；坏值/空值经 migrated 变成 `.system`。
    static var currentLanguage: BookAppLanguage {
        BookAppLanguage.migrated(from: UserDefaults.standard.string(forKey: appLanguageDefaultsKey)) // 读盘后迁移，调用方不必自己处理旧值
    }

    /// 给 SwiftUI / String(format:) 用的 Locale，system 时按本机映射到八种之一。
    static var activeLocale: Locale {
        Locale(identifier: languageCode(for: currentLanguage)) // 用内部 BCP-47，不是系统 Locale 原串
    }

    /// 按当前界面语言取目录条目。缺 key 时目录层决定回退，这里不写死中文。
    static func string(_ key: String) -> String {
        BookL10nCatalog.string(forKey: key, language: currentLanguage) // 单一入口，View 禁止直接碰 Catalog
    }

    /// 带格式参数的目录条目，locale 用 activeLocale，保证小数/复数按界面语言走。
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let template = string(key) // 先取模板，再 format，避免 Catalog 自己做一次格式化
        return String(format: template, locale: activeLocale, arguments: arguments) // 显式 locale，防止跟系统地区而不是界面语言
    }

    /// 把产品语言枚举收成目录用的 BCP-47。`.system` 在这里解析，不在用户点选时写死。
    private static func languageCode(for language: BookAppLanguage) -> String {
        switch language {
        case .system:
            let id = Locale.current.identifier.lowercased() // 本机地区，只用来选八种之一
            if id.hasPrefix("zh") { return "zh-Hans" } // 所有中文地区都落到简体目录
            if id.hasPrefix("ja") { return "ja" }
            if id.hasPrefix("de") { return "de" }
            if id.hasPrefix("fr") { return "fr" }
            if id.hasPrefix("it") { return "it" }
            if id.hasPrefix("el") { return "el" }
            if id == "la" || id.hasPrefix("la_") { return "la" } // 拉丁语少见，兼容 la 与 la_XX
            return "en" // 未覆盖的系统语言一律英文，避免空白
        case .zhHans: return "zh-Hans" // 目录里的简体键，不是 zh
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

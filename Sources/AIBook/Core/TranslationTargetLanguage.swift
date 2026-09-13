import Foundation

/// 译文目标语言。值对象，读写在 `TranslationTargetLanguageStore`。`followAppLanguage` 在使用时解析。
enum TranslationTargetLanguage: String, CaseIterable, Identifiable, Codable {
    case followAppLanguage
    case zhHans = "zh-Hans" // 落盘 BCP-47，与界面语言枚举对齐
    case en
    case ja
    case de
    case fr
    case it
    case la
    case el

    /// Identifiable id，等于 rawValue，和 UserDefaults 一致。
    var id: String { rawValue }

    /// 读盘迁移：空值、乱值变成跟随界面语言，读者从名字知道会回退。
    static func migrated(from stored: String?) -> TranslationTargetLanguage {
        guard let stored, !stored.isEmpty else { return .followAppLanguage } // 从未选过
        return TranslationTargetLanguage(rawValue: stored) ?? .followAppLanguage // 旧中文标题等非法值
    }

    /// 使用时把「跟随界面语言」收成具体语言。点选时不要拷成具体值，否则改界面语言不会影响下次翻译。
    func resolved(
        appLanguage: BookAppLanguage,
        systemLocaleIdentifier: String = Locale.current.identifier
    ) -> TranslationTargetLanguage {
        guard self == .followAppLanguage else { return self } // 用户已钉死某种语言
        switch appLanguage {
        case .system:
            return Self.from(localeIdentifier: systemLocaleIdentifier) // 界面也跟系统时，译文跟同一套映射
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

    /// 设置页/菜单上的显示名，走目录。
    var localizedName: String {
        BookL10n.string(localizationKey) // 跟随项和具体语言分 key
    }

    /// 写进提示词的 BCP-47。调用前必须先 resolved，禁止对 `.followAppLanguage` 取这个值。
    var bcp47Identifier: String {
        precondition(self != .followAppLanguage) // 未 resolved 就写提示词会把「跟随」当语言名
        return rawValue
    }

    /// 提示词里的英文语言名。目标语言必须写死，不能跟界面语言走。
    var promptLanguageName: String {
        switch self {
        case .followAppLanguage:
            return "Follow application language" // 只应出现在调试；拼提示词前应已 resolved
        case .zhHans:
            return "Modern Simplified Chinese" // 古文原文时要求现代白话文，见翻译合同
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

    /// 目录 key：跟随项单独一条，具体语言复用界面语言那套 language.*。
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

    /// 把系统 Locale 标识映射到具体目标语言，未覆盖的当英文。
    private static func from(localeIdentifier: String) -> TranslationTargetLanguage {
        let identifier = localeIdentifier.lowercased()
        if identifier.hasPrefix("zh") { return .zhHans }
        if identifier.hasPrefix("ja") { return .ja }
        if identifier.hasPrefix("de") { return .de }
        if identifier.hasPrefix("fr") { return .fr }
        if identifier.hasPrefix("it") { return .it }
        if identifier.hasPrefix("el") { return .el }
        if identifier == "la" || identifier.hasPrefix("la_") || identifier.hasPrefix("la-") {
            return .la // 兼容 la、la_VA、la-VA
        }
        return .en
    }
}

/// 译文目标语言的读写。键只在这里定义，禁止各处写死 `aiBook.translationTargetLanguage`。
enum TranslationTargetLanguageStore {
    /// 持久化键，和 AppSettings.Keys 一样集中定义。
    static let key = "aiBook.translationTargetLanguage"

    /// 读盘并迁移坏值。
    static func load(
        from defaults: UserDefaults = .standard
    ) -> TranslationTargetLanguage {
        TranslationTargetLanguage.migrated(
            from: defaults.string(forKey: key) // 缺 key 时 migrated 会给 followAppLanguage
        )
    }

    /// 写入 rawValue。调用方应传入用户点选的值，不要传入已 resolved 的具体语言（除非用户钉死了）。
    static func save(
        _ language: TranslationTargetLanguage,
        to defaults: UserDefaults = .standard
    ) {
        defaults.set(language.rawValue, forKey: key)
    }
}

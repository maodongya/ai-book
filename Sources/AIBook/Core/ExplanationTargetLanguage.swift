import Foundation

/// 讲解语言的读写。语言值复用 `TranslationTargetLanguage` 的具体语，键与译文分开。
enum ExplanationTargetLanguageStore {
    /// 当前右页显示的讲解语言。
    static let key = "aiBook.explanationTargetLanguage"

    /// 下次讲解要生成的语言。
    static let selectionKey = "aiBook.explanationTargetLanguages"

    /// 读当前显示语言。没有或坏值时收成当时的界面语言。
    static func load(
        appLanguage: BookAppLanguage,
        from defaults: UserDefaults = .standard
    ) -> TranslationTargetLanguage {
        if let stored = defaults.string(forKey: key),
           let language = TranslationTargetLanguage(rawValue: stored),
           language != .followAppLanguage {
            return language
        }
        return TranslationTargetLanguage.matching(appLanguage: appLanguage)
    }

    /// 写入当前显示语言。跟随项不落盘。
    static func save(
        _ language: TranslationTargetLanguage,
        to defaults: UserDefaults = .standard
    ) {
        guard language != .followAppLanguage else { return }
        defaults.set(language.rawValue, forKey: key)
    }

    /// 读多选。没有新键时，收成当时的界面语言一种。
    static func loadSelection(
        appLanguage: BookAppLanguage,
        from defaults: UserDefaults = .standard
    ) -> [TranslationTargetLanguage] {
        if let stored = defaults.stringArray(forKey: selectionKey) {
            let languages = TranslationTargetLanguage.orderedSelection(
                stored.compactMap { TranslationTargetLanguage(rawValue: $0) }
            )
            if !languages.isEmpty { return languages }
        }
        return [TranslationTargetLanguage.matching(appLanguage: appLanguage)]
    }

    /// 写入多选。空数组不落盘，避免下次读成迁移前的单选。
    static func saveSelection(
        _ languages: [TranslationTargetLanguage],
        to defaults: UserDefaults = .standard
    ) {
        let ordered = TranslationTargetLanguage.orderedSelection(languages)
        guard !ordered.isEmpty else { return }
        defaults.set(ordered.map(\.rawValue), forKey: selectionKey)
    }
}

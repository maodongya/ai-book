import Foundation

/// 把 BCP-47 语言 ID 收成读者看得懂的名称。
enum IOSLanguageLabels {
    static func displayName(for languageID: String) -> String {
        if let lang = TranslationTargetLanguage(rawValue: languageID) {
            return lang.localizedName
        }
        return languageID
    }
}
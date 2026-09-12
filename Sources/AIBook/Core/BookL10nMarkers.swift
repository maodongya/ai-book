import Foundation

/// Detect persisted or localized system chat markers (API history filtering).
enum BookL10nMarkers {
    static func isClassicSupplementIntro(_ content: String) -> Bool {
        content.hasPrefix(ClassicLiteratureSupplement.capabilityLabel)
            || content.hasPrefix("名著补充")
    }

    static func isReadingAssistantWelcome(_ content: String) -> Bool {
        content.hasPrefix(BookL10n.string("vm.chat.welcomeAssistant"))
            || content.hasPrefix("右页是你的读书助手")
    }

    static func isEvolutionWelcome(_ content: String) -> Bool {
        content.hasPrefix(BookL10n.string("vm.chat.welcomeEvolution"))
            || content.hasPrefix("这是 AI 进化选项卡")
    }

    static func isTranslationTaskMessage(_ content: String) -> Bool {
        let word = BookL10n.string("vm.display.wordTranslation")
        let paragraph = BookL10n.string("vm.display.paragraphTranslation")
        return content.hasPrefix(word)
            || content.hasPrefix(paragraph)
            || content.hasPrefix("生成逐字翻译")
            || content.hasPrefix("生成整段翻译")
            || content.contains("【生成逐字翻译】")
            || content.contains("【生成整段翻译】")
    }
}

import Foundation

/// 识别系统注入的聊天标记（欢迎语、任务头），用来从 API 历史里滤掉。不负责生成这些文案。
enum BookL10nMarkers {
    /// 是否为名著补充能力说明头。中英/旧文案都要认，否则旧会话会漏滤。
    static func isClassicSupplementIntro(_ content: String) -> Bool {
        content.hasPrefix(ClassicLiteratureSupplement.capabilityLabel) // 现行能力标签，改文案时新旧会话仍要能识别
            || content.hasPrefix("名著补充") // 历史中文前缀，旧落盘记录没有走目录
    }

    /// 是否为右页读书助手欢迎语。目录现行文案和历史中文都算。
    static func isReadingAssistantWelcome(_ content: String) -> Bool {
        content.hasPrefix(BookL10n.string("vm.chat.welcomeAssistant")) // 当前语言下的欢迎语，语言一切换前缀就变
            || content.hasPrefix("右页是你的读书助手") // 未本地化前的中文欢迎语，旧 transcript 仍在
    }

    /// 是否为进化选项卡欢迎语。同样兼容目录与历史中文。
    static func isEvolutionWelcome(_ content: String) -> Bool {
        content.hasPrefix(BookL10n.string("vm.chat.welcomeEvolution")) // 当前语言进化欢迎语
            || content.hasPrefix("这是 AI 进化选项卡") // 历史中文欢迎语
    }

    /// 是否为翻译任务提示（逐字/整段）。旧【】标记也要认，避免任务消息被当作用户闲聊送进模型。
    static func isTranslationTaskMessage(_ content: String) -> Bool {
        let word = BookL10n.string("vm.display.wordTranslation") // 现行「逐字翻译」展示名，随界面语言变
        let paragraph = BookL10n.string("vm.display.paragraphTranslation") // 现行「整段翻译」展示名
        return content.hasPrefix(word) // 新会话用目录前缀
            || content.hasPrefix(paragraph)
            || content.hasPrefix("生成逐字翻译") // 未本地化时的中文任务头
            || content.hasPrefix("生成整段翻译")
            || content.contains("【生成逐字翻译】") // 更早的书名号标记，夹在正文里也要滤
            || content.contains("【生成整段翻译】")
    }
}

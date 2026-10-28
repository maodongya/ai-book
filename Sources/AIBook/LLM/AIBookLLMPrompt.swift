import Foundation

/// 大模型对话的三种独立模式：system 提示词与 API 历史互不共享。
enum AIBookLLMPrompt {
    /// 读书助手 / 名著补充 / 翻译。各模式单独请求。
    enum Mode: Equatable {
        case readingAssistant
        case paragraphExplanation(TranslationTargetLanguage)
        case classicLiteratureSupplement
        case translation

        /// 该模式的 system 提示，从对应 persona 取，这里不写第二份。
        var systemPrompt: String {
            switch self {
            case .readingAssistant:
                return ReadingAssistant.systemPrompt
            case .paragraphExplanation(let language):
                return ExplanationPromptBuilder.systemPrompt(targetLanguage: language)
            case .classicLiteratureSupplement:
                return ClassicLiteratureSupplement.systemPrompt
            case .translation:
                return TranslationAssistant.systemPrompt
            }
        }

        /// 各模式独立请求，不携带其它模式的对话历史。
        var apiHistory: [ChatMessage] { [] } // 有意恒空，避免讲解记录进翻译
    }
}

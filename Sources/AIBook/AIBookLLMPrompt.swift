import Foundation

/// 大模型对话的三种独立模式：system 提示词与 API 历史互不共享。
enum AIBookLLMPrompt {
    enum Mode: Equatable {
        case readingAssistant
        case classicLiteratureSupplement
        case translation

        var systemPrompt: String {
            switch self {
            case .readingAssistant:
                return ReadingAssistant.systemPrompt
            case .classicLiteratureSupplement:
                return ClassicLiteratureSupplement.systemPrompt
            case .translation:
                return TranslationAssistant.systemPrompt
            }
        }

        /// 各模式独立请求，不携带其它模式的对话历史。
        var apiHistory: [ChatMessage] { [] }
    }
}

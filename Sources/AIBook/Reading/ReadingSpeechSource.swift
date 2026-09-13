import Foundation

/// 朗读内容来源，供工具栏与状态展示区分原文 / 译文 / 讲解。
enum SpeechSource: Equatable {
    case originalFull
    case originalSelection
    case translationFull
    case translationSelection
    case explanationFull
    case explanationSelection
    case aiReply

    var icon: String {
        switch self {
        case .originalFull, .originalSelection: return "text.book.closed"
        case .translationFull, .translationSelection: return "character.book.closed"
        case .explanationFull, .explanationSelection: return "sparkles.text.clipboard"
        case .aiReply: return "bubble.left.and.text.bubble.right"
        }
    }
}

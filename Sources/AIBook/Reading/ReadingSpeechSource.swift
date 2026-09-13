import Foundation

/// 朗读内容来源，供工具栏与状态展示区分原文 / 译文 / 讲解。
enum SpeechSource: Equatable {
    case originalFull // 左页全文
    case originalSelection // 左页当前选区
    case translationFull // 右页译文全文
    case translationSelection // 右页译文选区
    case explanationFull // 讲解气泡全文
    case explanationSelection // 讲解里选中的一段
    case aiReply // 刚生成的这一条回复，朗读完不改来源记忆

    /// 工具栏图标：原文书、译文书、讲解火花、回复气泡。
    var icon: String {
        switch self {
        case .originalFull, .originalSelection: return "text.book.closed" // 原文用合着的书
        case .translationFull, .translationSelection: return "character.book.closed" // 译文用带字书，和原文区分
        case .explanationFull, .explanationSelection: return "sparkles.text.clipboard" // 讲解跟右页火花一致
        case .aiReply: return "bubble.left.and.text.bubble.right" // 回复不是页内正文
        }
    }
}

import Foundation

/// 历史该进读书对话还是进化对话，两套不能混。
enum ReadingPromptContext {
    case reading // 讲解/翻译对话，不进进化队列
    case evolution // 分析、改文件、跟进，单独一份历史
}

/// none=讲解；evolution/analysis/followUp 走进化链。
enum ReadingEvolutionRunKind {
    case none // 普通讲解，不碰优化队列
    case analysis // 只出建议，不改仓库
    case evolution // 按命令号改文件并可能接着打包
    case followUp // 上一轮进化的追问，不新开命令号
}

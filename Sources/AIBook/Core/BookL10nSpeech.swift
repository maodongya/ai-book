import Foundation

/// 朗读引擎档位的显示名。只做目录映射，不改语速或音色。
extension SpeechEngineMode {
    /// 设置页引擎档位名称。
    var localizedName: String {
        switch self {
        case .fast: return BookL10n.string("speech.engine.fast") // 快速档菜单名
        case .balanced: return BookL10n.string("speech.engine.balanced") // 均衡档菜单名
        case .natural: return BookL10n.string("speech.engine.natural") // 自然档菜单名
        case .relaxed: return BookL10n.string("speech.engine.relaxed") // 舒缓档菜单名
        }
    }
}

/// 朗读语言深度档位的显示名和说明。
extension SpeechLanguageMode {
    /// 语言档位短名。
    var localizedName: String {
        switch self {
        case .efficient: return BookL10n.string("speech.lang.efficient") // 高效档
        case .balanced: return BookL10n.string("speech.engine.balanced") // 沿用引擎均衡条文案，改名要两处一起想
        case .deep: return BookL10n.string("speech.lang.deep") // 深度档
        }
    }

    /// 语言档位一句话说明，设置页副文案。
    var localizedDescription: String {
        switch self {
        case .efficient: return BookL10n.string("speech.desc.lang.efficient") // 高效档说明，和 name 分 key
        case .balanced: return BookL10n.string("speech.desc.lang.balanced") // 均衡档说明走 lang 键，与 name 的 engine 键不同
        case .deep: return BookL10n.string("speech.desc.lang.deep") // 深度档说明
        }
    }
}

extension SpeechEngineMode {
    /// 引擎档位一句话说明。
    var localizedDescription: String {
        switch self {
        case .fast: return BookL10n.string("speech.desc.fast") // 快速档说明
        case .balanced: return BookL10n.string("speech.desc.balanced") // 均衡档说明
        case .natural: return BookL10n.string("speech.desc.natural") // 自然档说明
        case .relaxed: return BookL10n.string("speech.desc.relaxed") // 舒缓档说明
        }
    }
}

/// 朗读内容来源的菜单标签：原文/译文/讲解 × 全文或选区，外加 AI 回复。
extension SpeechSource {
    /// 来源菜单上的一行字。
    var label: String {
        switch self {
        case .originalFull: return BookL10n.string("speech.source.originalFull") // 左页全文
        case .originalSelection: return BookL10n.string("speech.source.originalSelection") // 左页当前选区
        case .translationFull: return BookL10n.string("speech.source.translationFull") // 译文全文
        case .translationSelection: return BookL10n.string("speech.source.translationSelection") // 译文选区
        case .explanationFull: return BookL10n.string("speech.source.explanationFull") // 讲解全文
        case .explanationSelection: return BookL10n.string("speech.source.explanationSelection") // 讲解选区
        case .aiReply: return BookL10n.string("speech.source.aiReply") // 最新一条助手回复
        }
    }
}

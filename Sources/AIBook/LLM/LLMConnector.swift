import Foundation

/// 读书用的多模型连接说明与配置判断。真正发请求在 LLMService。
enum LLMConnector {
    static let capabilityLabel = "多模型"

    /// 关于页：已内置提供商名，用 · 拼接。
    static var supportedSummary: String {
        LLMProvider.allCases.map(\.rawValue).joined(separator: " · ")
    }

    static var aboutLines: [String] {
        [
            "顶栏右侧 AI 进化区可切换「大模型 API」/「Cursor 本地」；大模型通过 OpenAI 兼容接口连接各家模型，用于讲解与追问。",
            "已内置：\(supportedSummary)。",
            "美国常用模型已按各家当前默认填好：OpenAI gpt-6.1-sol、Anthropic claude-sonnet-5-5、Gemini gemini-4-hydrogen、xAI grok-4.7。",
            "设置页可同时配置多家 API Key（LLMProfileStore 按提供商独立存储），切换当前使用不会丢失其他配置。",
            "右页底部 LLMComposer 与 Cursor 对称：提供商/模型、原文节选占比、上下文占用、发送/停止与流式输出。",
        ]
    }

    /// 不要求 key 的提供商，空 key 也算配好。当前各家都要 Key。
    static func isConfigured(provider: LLMProvider, apiKey: String) -> Bool {
        !provider.requiresAPIKey || !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 顶栏/状态：「提供商 · 模型」；模型空则只显示提供商。
    static func displayLabel(provider: LLMProvider, model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return provider.rawValue
        }
        return "\(provider.rawValue) · \(trimmed)"
    }
}

/// OpenAI 兼容提供商。rawValue 是界面上的名字，落盘也用它。
enum LLMProvider: String, CaseIterable, Identifiable, Codable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case gemini = "Gemini"
    case xai = "xAI"
    case deepSeek = "DeepSeek"
    case moonshot = "Moonshot"
    case qwen = "通义千问"
    case zhipu = "智谱"
    case custom = "自定义"

    /// 已从产品里拿掉的本机 Ollama。旧偏好里的这个名字要迁走。
    static let retiredLocalRawValue = "Ollama"

    var id: String { rawValue }

    /// 该提供商默认网关。自定义先给 OpenAI 地址，让用户改。
    var defaultBaseURL: String {
        switch self {
        case .openAI:
            return "https://api.openai.com/v1"
        case .anthropic:
            return "https://api.anthropic.com/v1" // Claude 的 OpenAI 兼容层
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta/openai"
        case .xai:
            return "https://api.x.ai/v1"
        case .deepSeek:
            return "https://api.deepseek.com/v1"
        case .moonshot:
            return "https://api.moonshot.cn/v1"
        case .qwen:
            return QwenBailianConfig.defaultBaseURL // 百炼地域在 QwenBailianConfig
        case .zhipu:
            return "https://open.bigmodel.cn/api/paas/v4"
        case .custom:
            return "https://api.openai.com/v1"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI:
            return "gpt-6.1-sol"
        case .anthropic:
            return "claude-sonnet-5-5"
        case .gemini:
            return "gemini-4-hydrogen"
        case .xai:
            return "grok-4.7"
        case .deepSeek:
            return "deepseek-chat"
        case .moonshot:
            return "moonshot-v1-8k"
        case .qwen:
            return QwenBailianConfig.defaultModel
        case .zhipu:
            return "glm-4-flash"
        case .custom:
            return "gpt-6.1-sol"
        }
    }

    /// 设置页和输入条里的可选模型。空数组表示只给文本框。
    var suggestedModels: [String] {
        switch self {
        case .openAI, .custom:
            return ["gpt-6.1-sol", "gpt-6-astra", "gpt-6-luna"]
        case .anthropic:
            return ["claude-sonnet-5-5", "claude-opus-5-5", "claude-haiku-5-5", "claude-fable-5-2"]
        case .gemini:
            return ["gemini-4-hydrogen"]
        case .xai:
            return ["grok-4.7", "grok-4.6", "grok-4.3"]
        case .qwen:
            return QwenBailianConfig.suggestedModels
        default:
            return []
        }
    }

    /// 当前档案里的名字不在建议列表时插到最前，避免 Picker 空选。
    func modelChoices(including current: String) -> [String] {
        var names = suggestedModels
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !names.contains(trimmed) {
            names.insert(trimmed, at: 0)
        }
        return names
    }

    /// Claude 4.7 及以后：请求里带非默认 temperature 会 400，所以整家都省略。
    var omitsSamplingTemperature: Bool {
        self == .anthropic
    }

    var requiresAPIKey: Bool { true }

    var showsAPIKeyField: Bool { true }

    var apiKeyFieldLabel: String {
        switch self {
        case .qwen:
            return BookL10n.string("llm.key.qwen")
        default:
            return BookL10n.string("llm.key.default")
        }
    }

    /// 设置页提供商旁的一句适用场景。
    var readingHint: String {
        switch self {
        case .openAI:
            return BookL10n.string("llm.hint.openai")
        case .anthropic:
            return BookL10n.string("llm.hint.anthropic")
        case .gemini:
            return BookL10n.string("llm.hint.gemini")
        case .xai:
            return BookL10n.string("llm.hint.xai")
        case .deepSeek:
            return BookL10n.string("llm.hint.deepseek")
        case .moonshot:
            return BookL10n.string("llm.hint.moonshot")
        case .qwen:
            return BookL10n.format("llm.hint.qwen", QwenBailianConfig.defaultBaseURL)
        case .zhipu:
            return BookL10n.string("llm.hint.zhipu")
        case .custom:
            return BookL10n.string("llm.hint.custom")
        }
    }

    /// 旧档里的 Ollama 不再是可选项，读出来当没有。
    static func resolved(stored raw: String?, fallback: LLMProvider) -> LLMProvider {
        guard let raw, !raw.isEmpty, raw != retiredLocalRawValue else {
            return fallback
        }
        return LLMProvider(rawValue: raw) ?? fallback
    }

    /// 发送前给用户看的接收方：公司名加主机，避免只写商品名。
    func outboundRecipient(baseURL: String) -> String {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = URL(string: trimmed)?.host
            ?? URL(string: defaultBaseURL)?.host
            ?? trimmed
        let company: String
        switch self {
        case .openAI:
            company = "OpenAI"
        case .anthropic:
            company = "Anthropic"
        case .gemini:
            company = "Google"
        case .xai:
            company = "xAI"
        case .deepSeek:
            company = "DeepSeek"
        case .moonshot:
            company = "Moonshot"
        case .qwen:
            company = BookL10n.string("privacy.company.alibaba")
        case .zhipu:
            company = BookL10n.string("privacy.company.zhipu")
        case .custom:
            company = BookL10n.string("privacy.company.custom")
        }
        return "\(company) (\(host))"
    }

    /// 本机 Ollama 默认地址或旧默认模型名。用来把迁走后仍写着 11434 的档案改回云端默认。
    static func looksLikeRetiredLocal(baseURL: String, model: String) -> Bool {
        let url = baseURL.lowercased()
        if url.contains("11434") || url.contains("ollama") { return true }
        let name = model.lowercased()
        return name == "llama3.2" || name.hasPrefix("llama3.2:")
    }
}

/// 发送前那一句：读书走当前提供商，进化走 Cursor。
@MainActor
enum OutboundNotice {
    static func sentence(for mode: RightPageTab, settings: AppSettings) -> String {
        switch mode {
        case .readingAssistant:
            return reading(settings: settings)
        }
    }

    static func reading(settings: AppSettings) -> String {
        let who = settings.bookProvider.outboundRecipient(baseURL: settings.bookBaseURL)
        return BookL10n.format("privacy.outbound", who)
    }
}

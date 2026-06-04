import Foundation

/// Multi-LLM connectivity for reading assistance (command #3).
enum LLMConnector {
    static let capabilityLabel = "多模型"

    static var supportedSummary: String {
        LLMProvider.allCases.map(\.rawValue).joined(separator: " · ")
    }

    static var aboutLines: [String] {
        [
            "顶栏右侧 AI 进化区可切换「大模型 API」/「Cursor 本地」；大模型通过 OpenAI 兼容接口连接各家模型，用于讲解与追问。",
            "已内置：\(supportedSummary)。",
            "设置页可同时配置多家 API Key（LLMProfileStore 按提供商独立存储），切换当前使用不会丢失其他配置。",
            "Ollama 本地默认可不填 API Key；设置页可自动扫描本机已 pull 的模型。支持 OLLAMA_HOST / OLLAMA_API_KEY 环境变量。",
            "右页底部 LLMComposer 与 Cursor 对称：提供商/模型、原文节选占比、上下文占用、发送/停止与流式输出。",
        ]
    }

    static func isConfigured(provider: LLMProvider, apiKey: String) -> Bool {
        !provider.requiresAPIKey || !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func displayLabel(provider: LLMProvider, model: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return provider.rawValue
        }
        return "\(provider.rawValue) · \(trimmed)"
    }
}

enum LLMProvider: String, CaseIterable, Identifiable, Codable {
    case openAI = "OpenAI"
    case deepSeek = "DeepSeek"
    case moonshot = "Moonshot"
    case qwen = "通义千问"
    case zhipu = "智谱"
    case ollama = "Ollama"
    case custom = "自定义"

    var id: String { rawValue }

    var defaultBaseURL: String {
        switch self {
        case .openAI:
            return "https://api.openai.com/v1"
        case .deepSeek:
            return "https://api.deepseek.com/v1"
        case .moonshot:
            return "https://api.moonshot.cn/v1"
        case .qwen:
            return QwenBailianConfig.defaultBaseURL
        case .zhipu:
            return "https://open.bigmodel.cn/api/paas/v4"
        case .ollama:
            return "http://127.0.0.1:11434/v1"
        case .custom:
            return "https://api.openai.com/v1"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI:
            return "gpt-4o-mini"
        case .deepSeek:
            return "deepseek-chat"
        case .moonshot:
            return "moonshot-v1-8k"
        case .qwen:
            return QwenBailianConfig.defaultModel
        case .zhipu:
            return "glm-4-flash"
        case .ollama:
            return "llama3.2"
        case .custom:
            return "gpt-4o-mini"
        }
    }

    var requiresAPIKey: Bool {
        self != .ollama
    }

    /// Settings UI shows an API Key field (required for most providers; optional for Ollama).
    var showsAPIKeyField: Bool {
        requiresAPIKey || self == .ollama
    }

    var apiKeyFieldLabel: String {
        switch self {
        case .qwen:
            return "API Key（百炼 sk-）"
        case .ollama:
            return "API Key（可选）"
        default:
            return "API Key"
        }
    }

    var readingHint: String {
        switch self {
        case .openAI:
            return "OpenAI 官方 API，适合通用阅读讲解。"
        case .deepSeek:
            return "DeepSeek 高性价比中文理解，适合长文阅读。"
        case .moonshot:
            return "Moonshot（Kimi）长上下文，适合整章阅读。"
        case .qwen:
            return "阿里云百炼通义千问（OpenAI 兼容）。默认北京地域 \(QwenBailianConfig.defaultBaseURL)，Key 在百炼控制台 API 页创建。"
        case .zhipu:
            return "智谱 GLM 系列，适合中文书籍与笔记解析。"
        case .ollama:
            return "本机 Ollama，离线可用；设置页可自动扫描已安装模型并选择。支持 OLLAMA_HOST 环境变量与可选 API Key。"
        case .custom:
            return "任意 OpenAI 兼容接口，自行填写地址与模型。"
        }
    }
}

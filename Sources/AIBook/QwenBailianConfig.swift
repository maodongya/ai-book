import Foundation

/// 阿里云百炼（Model Studio）OpenAI 兼容接口配置。
/// 参考：https://help.aliyun.com/zh/model-studio/compatibility-of-openai-with-dashscope
enum QwenBailianRegion: String, CaseIterable, Identifiable, Codable, Hashable {
    case beijing
    case singapore
    case virginia

    var id: String { rawValue }

    var label: String {
        switch self {
        case .beijing: return "华北2（北京）"
        case .singapore: return "新加坡（国际）"
        case .virginia: return "美国（弗吉尼亚）"
        }
    }

    /// OpenAI 兼容 Base URL（SDK/应用内填写此项，勿带 `/chat/completions`）。
    var compatibleBaseURL: String {
        switch self {
        case .beijing:
            return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .singapore:
            return "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
        case .virginia:
            return "https://dashscope-us.aliyuncs.com/compatible-mode/v1"
        }
    }

    var consoleHint: String {
        switch self {
        case .beijing:
            return "在百炼控制台「华北2（北京）」创建 API Key，与下方 Base URL 地域一致。"
        case .singapore:
            return "在百炼控制台「国际（新加坡）」创建 API Key，勿与北京 Key 混用。"
        case .virginia:
            return "在百炼控制台「美国（弗吉尼亚）」创建 API Key。"
        }
    }

    static func detect(from baseURL: String) -> QwenBailianRegion? {
        let normalized = baseURL.lowercased()
        if normalized.contains("dashscope-intl") { return .singapore }
        if normalized.contains("dashscope-us") { return .virginia }
        if normalized.contains("dashscope.aliyuncs.com") { return .beijing }
        return nil
    }
}

enum QwenBailianConfig {
    static let consoleURL = "https://bailian.console.aliyun.com/?tab=api#/api"
    static let apiKeyHelpURL = "https://help.aliyun.com/zh/model-studio/get-api-key"
    static let compatibilityDocURL = "https://help.aliyun.com/zh/model-studio/compatibility-of-openai-with-dashscope"

    static let defaultRegion: QwenBailianRegion = .beijing
    static let defaultBaseURL = QwenBailianRegion.beijing.compatibleBaseURL
    static let defaultModel = "qwen-plus"

    /// 读书场景常用模型（OpenAI 兼容接口 `model` 参数）。
    static let suggestedModels: [String] = [
        "qwen-plus",
        "qwen-plus-latest",
        "qwen3.6-plus",
        "qwen3.5-plus",
        "qwen-flash",
        "qwen3.6-flash",
        "qwen-long",
        "qwen-max",
        "qwen-turbo",
    ]

    static func normalizedBaseURL(_ baseURL: String) -> String {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultBaseURL }

        if trimmed.hasSuffix("/chat/completions") {
            trimmed = String(trimmed.dropLast("/chat/completions".count))
        }
        return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func resolveAPIKey(stored: String) -> String {
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }

        if let env = ProcessInfo.processInfo.environment["DASHSCOPE_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }

        return loadKeyFromLocalFiles() ?? ""
    }

    static func loadKeyFromLocalFiles() -> String? {
        for url in localEnvCandidates() {
            if let value = parseEnvFile(at: url, key: "DASHSCOPE_API_KEY") {
                return value
            }
        }
        return nil
    }

    static func localEnvCandidates() -> [URL] {
        var candidates: [URL] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        candidates.append(home.appendingPathComponent(".aibook/dashscope.env"))

        for root in CursorAPIKeyStore.projectRootCandidates() {
            candidates.append(root.appendingPathComponent("dashscope.local.env"))
            candidates.append(root.appendingPathComponent("ai-book/dashscope.local.env"))
            candidates.append(root.appendingPathComponent("cursor.local.env"))
            candidates.append(root.appendingPathComponent("ai-book/cursor.local.env"))
        }
        return candidates
    }

    private static func parseEnvFile(at url: URL, key: String) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        for line in content.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces) == key else { continue }
            let value = parts[1]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if !value.isEmpty { return value }
        }
        return nil
    }

    static func repairProfile(_ profile: LLMProfile) -> LLMProfile {
        var repaired = profile
        let base = profile.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if base.isEmpty {
            repaired.baseURL = defaultBaseURL
        } else if base.lowercased().contains("cn-hongkong.dashscope") {
            repaired.baseURL = defaultBaseURL
        } else {
            repaired.baseURL = normalizedBaseURL(base)
        }

        if repaired.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            repaired.model = defaultModel
        }

        return repaired
    }

    /// OpenAI 兼容请求附加参数（Function Calling 须关闭思考模式，见百炼文档）。
    static func requestExtras(model: String, includeTools: Bool) -> [String: Any] {
        guard includeTools else { return [:] }
        // qwen3.x 默认开启思考；与 tools 同用时官方示例均设 enable_thinking=false。
        return ["enable_thinking": false]
    }

    /// 工具循环中回传 assistant 消息（content 用空串；思考模型须保留 reasoning_content）。
    static func assistantToolCallMessage(
        content: String?,
        reasoning: String?,
        toolCalls: [[String: Any]]
    ) -> [String: Any] {
        var message: [String: Any] = ["role": "assistant"]
        let trimmedContent = content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        message["content"] = trimmedContent
        if let reasoning = reasoning?.trimmingCharacters(in: .whitespacesAndNewlines),
           !reasoning.isEmpty {
            message["reasoning_content"] = reasoning
        }
        message["tool_calls"] = toolCalls
        return message
    }

    static func preparedConfiguration(_ configuration: LLMConfiguration) -> LLMConfiguration {
        var profile = LLMProfile(
            apiKey: configuration.apiKey,
            baseURL: configuration.baseURL,
            model: configuration.model
        )
        profile = repairProfile(profile)
        return LLMConfiguration(
            provider: .qwen,
            baseURL: profile.baseURL,
            model: profile.model,
            apiKey: resolveAPIKey(stored: profile.apiKey)
        )
    }

    static func parseAPIErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            if let code = error["code"] as? String, !code.isEmpty {
                return "\(code): \(message)"
            }
            return message
        }

        if let message = json["message"] as? String {
            if let code = json["code"] as? String, !code.isEmpty {
                return "\(code): \(message)"
            }
            return message
        }

        return String(data: data, encoding: .utf8)
    }

    static func enrichError(_ message: String, baseURL: String) -> String {
        let lower = message.lowercased()
        var hints: [String] = []

        if lower.contains("api key") || lower.contains("incorrect") || lower.contains("unauthorized") || lower.contains("401") {
            hints.append("请在百炼控制台创建 API Key（格式 sk- 开头），与所选地域的 Base URL 一致。")
            hints.append("控制台：\(consoleURL)")
        }

        if lower.contains("model") && (lower.contains("not") || lower.contains("exist") || lower.contains("invalid")) {
            hints.append("模型名请从百炼文档的 OpenAI 兼容列表中选择，例如 qwen-plus、qwen3.6-plus。")
        }

        if lower.contains("reasoning") || lower.contains("enable_thinking") || lower.contains("thinking") {
            hints.append("若使用 qwen3.x 进行工具调用（AI 进化），程序已自动设置 enable_thinking=false；普通读书对话可正常使用思考模式。")
        }

        if let region = QwenBailianRegion.detect(from: baseURL),
           lower.contains("access") || lower.contains("denied") || lower.contains("forbidden") {
            hints.append(region.consoleHint)
        }

        guard !hints.isEmpty else { return message }
        return ([message] + hints).joined(separator: "\n\n")
    }
}

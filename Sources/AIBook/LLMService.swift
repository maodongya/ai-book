import Foundation

struct LLMConfiguration {
    let provider: LLMProvider
    let baseURL: String
    let model: String
    let apiKey: String
}

enum LLMStreamEvent {
    case textDelta(String)
    case done(text: String)
    case error(String)
}

typealias LLMToolStreamPartial = (_ reasoningDelta: String?, _ contentDelta: String?) -> Void

enum LLMServiceError: LocalizedError {
    case missingAPIKey(provider: LLMProvider)
    case invalidURL
    case invalidResponse
    case apiError(String, provider: LLMProvider)
    case cancelled
    case contextWindowExceeded(used: Int, limit: Int, model: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "请先在设置中为「\(provider.rawValue)」配置 API Key。"
        case .invalidURL:
            return "API 地址无效，请检查设置。"
        case .invalidResponse:
            return "大模型返回了无法解析的响应。"
        case .apiError(let message, let provider):
            return LLMServiceErrorPresenter.enrich(message, provider: provider)
        case .cancelled:
            return "已取消请求。"
        case .contextWindowExceeded(let used, let limit, let model):
            return "当前模型 \(model) 上下文 token 已超限（\(TokenDisplay.format(used))/\(TokenDisplay.format(limit))）。请清空对话或换用更大上下文的模型。"
        }
    }
}

enum LLMServiceErrorPresenter {
    static func message(for error: Error, provider: LLMProvider, baseURL: String? = nil) -> String {
        if let llmError = error as? LLMServiceError {
            return llmError.errorDescription ?? error.localizedDescription
        }
        if provider == .ollama, let urlError = error as? URLError {
            return OllamaConfig.enrichError(
                urlError.localizedDescription,
                host: OllamaConfig.resolvedHost(baseURL: baseURL ?? OllamaConfig.defaultOpenAIBaseURL)
            )
        }
        return enrich(error.localizedDescription, provider: provider, baseURL: baseURL)
    }

    static func enrich(_ message: String, provider: LLMProvider, baseURL: String? = nil) -> String {
        let lower = message.lowercased()

        if provider == .ollama {
            let host = OllamaConfig.resolvedHost(baseURL: baseURL ?? OllamaConfig.defaultOpenAIBaseURL)
            if lower.contains("api key") || lower.contains("apikey") || lower.contains("incorrect")
                || lower.contains("connection") || lower.contains("connect")
                || lower.contains("refused") || lower.contains("network")
                || lower.contains("timed out") || lower.contains("无法连接")
                || lower.contains("model") || OllamaConfig.isToolsUnsupportedAPIError(message)
                || lower.contains("invalid response") || lower.contains("无法解析") {
                return OllamaConfig.enrichError(message, host: host)
            }
        }

        guard lower.contains("api key") || lower.contains("apikey") || lower.contains("incorrect") else {
            return message
        }

        switch provider {
        case .qwen:
            return QwenBailianConfig.enrichError(
                """
                \(message)

                提示：在百炼「API」页创建 Key（sk- 开头），地域须与 Base URL 一致（默认北京：\(QwenBailianConfig.defaultBaseURL)）。也可设置环境变量 DASHSCOPE_API_KEY 或 ai-book/dashscope.local.env。
                """,
                baseURL: baseURL ?? QwenBailianConfig.defaultBaseURL
            )
        case .zhipu:
            return """
            \(message)

            提示：请在智谱开放平台创建 Key，并在设置中为「智谱」单独保存。
            """
        case .ollama:
            return OllamaConfig.enrichError(message, host: OllamaConfig.resolvedHost(baseURL: baseURL ?? OllamaConfig.defaultOpenAIBaseURL))
        default:
            return """
            \(message)

            提示：请在设置中为当前提供商「\(provider.rawValue)」填写正确的 API Key，或使用「测试连接」验证。
            """
        }
    }
}

final class LLMService {
    private var activeTask: URLSessionTask?
    private var activeBytesTask: Task<Void, Never>?
    private var activeCompletionTask: Task<LLMCompletionResult, Error>?

    func cancel() {
        cancelInFlightNetwork()
        activeCompletionTask?.cancel()
        activeCompletionTask = nil
    }

    /// Cancels URLSession work only — safe to call from inside an active completion task.
    private func cancelInFlightNetwork() {
        activeTask?.cancel()
        activeTask = nil
        activeBytesTask?.cancel()
        activeBytesTask = nil
    }

    private func normalizedConfiguration(_ configuration: LLMConfiguration) -> LLMConfiguration {
        LLMConfiguration(
            provider: configuration.provider,
            baseURL: configuration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            model: configuration.model.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: LLMProfileStore.sanitizedKey(configuration.apiKey)
        )
    }

    private func preparedConfiguration(_ configuration: LLMConfiguration) async -> LLMConfiguration {
        let config = normalizedConfiguration(configuration)
        if config.provider == .qwen {
            return QwenBailianConfig.preparedConfiguration(config)
        }
        guard config.provider == .ollama else { return config }

        let baseURL = OllamaConfig.normalizedOpenAIBaseURL(config.baseURL)
        let apiKey = OllamaConfig.resolveAPIKey(stored: config.apiKey)
        let model = await OllamaConfig.resolveModelForRequest(
            config.model,
            baseURL: baseURL,
            apiKey: apiKey
        )
        return LLMConfiguration(
            provider: .ollama,
            baseURL: baseURL,
            model: model,
            apiKey: apiKey
        )
    }

    /// Lightweight ping to verify provider connectivity (command #3).
    func testConnection(configuration: LLMConfiguration) async throws {
        let configuration = await preparedConfiguration(configuration)
        if configuration.provider.requiresAPIKey && configuration.apiKey.isEmpty {
            throw LLMServiceError.missingAPIKey(provider: configuration.provider)
        }

        let trimmedBaseURL = configuration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions") else {
            throw LLMServiceError.invalidURL
        }

        let payload: [String: Any] = [
            "model": configuration.model,
            "messages": [
                ["role": "user", "content": "ping"],
            ],
            "max_tokens": 1,
            "temperature": 0,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorizationHeader(to: &request, apiKey: configuration.apiKey)
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMServiceError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            var message = parseErrorMessage(from: data, provider: configuration.provider)
                ?? "连接失败（HTTP \(httpResponse.statusCode)）"
            if configuration.provider == .qwen {
                message = QwenBailianConfig.enrichError(message, baseURL: configuration.baseURL)
            } else if configuration.provider == .ollama {
                message = OllamaConfig.enrichError(
                    message,
                    host: OllamaConfig.resolvedHost(baseURL: configuration.baseURL)
                )
            }
            throw LLMServiceError.apiError(message, provider: configuration.provider)
        }
    }

    /// Non-streaming or streaming chat completion with OpenAI-compatible tool calling.
    func completeWithTools(
        messages: [[String: Any]],
        tools: [[String: Any]],
        configuration: LLMConfiguration,
        streamPartial: LLMToolStreamPartial? = nil
    ) async throws -> LLMCompletionResult {
        let configuration = await preparedConfiguration(configuration)
        if configuration.provider.requiresAPIKey && configuration.apiKey.isEmpty {
            throw LLMServiceError.missingAPIKey(provider: configuration.provider)
        }

        let trimmedBaseURL = configuration.baseURL
        guard let url = URL(string: trimmedBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions") else {
            throw LLMServiceError.invalidURL
        }

        let useStreaming = streamPartial != nil
        var includeTools = true
        if configuration.provider == .ollama {
            includeTools = await OllamaConfig.modelSupportsTools(
                baseURL: configuration.baseURL,
                model: configuration.model,
                apiKey: configuration.apiKey
            )
        }

        for toolsAttempt in 0 ..< 2 {
            do {
                return try await performWithTransientRetry {
                    var payload: [String: Any] = [
                        "model": configuration.model,
                        "messages": messages,
                        "temperature": 0.2,
                        "stream": useStreaming,
                    ]
                    if includeTools {
                        payload["tools"] = tools
                        payload["tool_choice"] = "auto"
                    }
                    if configuration.provider == .qwen {
                        for (key, value) in QwenBailianConfig.requestExtras(
                            model: configuration.model,
                            includeTools: includeTools
                        ) {
                            payload[key] = value
                        }
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 300
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    self.applyAuthorizationHeader(to: &request, apiKey: configuration.apiKey)
                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                    if useStreaming {
                        self.cancel()
                        let task = Task {
                            try await self.streamCompleteWithTools(
                                request: request,
                                configuration: configuration,
                                streamPartial: streamPartial!
                            )
                        }
                        self.activeCompletionTask = task
                        defer { self.activeCompletionTask = nil }
                        return try await task.value
                    }

                    self.cancel()
                    let (data, response) = try await withTaskCancellationHandler {
                        try await URLSession.shared.data(for: request)
                    } onCancel: {
                        Task { @MainActor in self.cancel() }
                    }

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMServiceError.invalidResponse
                    }

                    guard (200 ... 299).contains(httpResponse.statusCode) else {
                        var message = self.parseErrorMessage(from: data, provider: configuration.provider)
                            ?? "请求失败（HTTP \(httpResponse.statusCode)）"
                        if configuration.provider == .qwen {
                            message = QwenBailianConfig.enrichError(message, baseURL: configuration.baseURL)
                        } else if configuration.provider == .ollama {
                            message = OllamaConfig.enrichError(
                                message,
                                host: OllamaConfig.resolvedHost(baseURL: configuration.baseURL)
                            )
                        }
                        throw LLMServiceError.apiError(message, provider: configuration.provider)
                    }

                    return try self.parseCompletionResult(from: data)
                }
            } catch let error as LLMServiceError {
                if case .apiError(let message, .ollama) = error,
                   includeTools,
                   toolsAttempt == 0,
                   OllamaConfig.isToolsUnsupportedAPIError(message) {
                    includeTools = false
                    continue
                }
                throw error
            }
        }

        throw LLMServiceError.invalidResponse
    }

    private func performWithTransientRetry<T>(
        maxAttempts: Int = 2,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0 ..< maxAttempts {
            do {
                return try await operation()
            } catch is CancellationError {
                throw LLMServiceError.cancelled
            } catch {
                lastError = error
                guard attempt + 1 < maxAttempts, isTransientNetworkError(error) else {
                    throw error
                }
                try await Task.sleep(nanoseconds: 800_000_000)
            }
        }
        throw lastError ?? LLMServiceError.invalidResponse
    }

    private func isTransientNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost,
                 .notConnectedToInternet,
                 .timedOut,
                 .cannotConnectToHost,
                 .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        let message = (
            (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        ).lowercased()
        return message.contains("network connection was lost")
            || message.contains("似乎已断开与互联网的连接")
            || message.contains("timed out")
            || message.contains("connection reset")
    }

    private func streamCompleteWithTools(
        request: URLRequest,
        configuration: LLMConfiguration,
        streamPartial: LLMToolStreamPartial
    ) async throws -> LLMCompletionResult {
        try Task.checkCancellation()
        cancelInFlightNetwork()

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMServiceError.invalidResponse
        }

        if !(200 ... 299).contains(httpResponse.statusCode) {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            var message = parseErrorMessage(from: errorData, provider: configuration.provider)
                ?? "请求失败（HTTP \(httpResponse.statusCode)）"
            if configuration.provider == .qwen {
                message = QwenBailianConfig.enrichError(message, baseURL: configuration.baseURL)
            } else if configuration.provider == .ollama {
                message = OllamaConfig.enrichError(
                    message,
                    host: OllamaConfig.resolvedHost(baseURL: configuration.baseURL)
                )
            }
            throw LLMServiceError.apiError(message, provider: configuration.provider)
        }

        var accumulatedContent = ""
        var accumulatedReasoning = ""
        var toolCallsByIndex: [Int: (id: String, name: String, arguments: String)] = [:]
        var streamUsage = LLMTokenUsage.zero

        for try await line in bytes.lines {
            try Task.checkCancellation()

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("data:") else { continue }

            let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { continue }

            guard
                let jsonData = payload.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else {
                continue
            }

            let chunkUsage = parseUsage(from: json)
            if chunkUsage.totalTokens > 0 {
                streamUsage = chunkUsage
            }

            guard
                let choices = json["choices"] as? [[String: Any]],
                let first = choices.first,
                let delta = first["delta"] as? [String: Any]
            else {
                continue
            }

            if let reasoning = delta["reasoning_content"] as? String ?? delta["reasoning"] as? String,
               !reasoning.isEmpty {
                accumulatedReasoning += reasoning
                streamPartial(reasoning, nil)
            }

            if let content = delta["content"] as? String, !content.isEmpty {
                accumulatedContent += content
                streamPartial(nil, content)
            }

            if let rawCalls = delta["tool_calls"] as? [[String: Any]] {
                for call in rawCalls {
                    let index = call["index"] as? Int ?? toolCallsByIndex.count
                    var existing = toolCallsByIndex[index] ?? (id: "", name: "", arguments: "")
                    if let id = call["id"] as? String, !id.isEmpty {
                        existing.id = id
                    }
                    if let function = call["function"] as? [String: Any] {
                        if let name = function["name"] as? String, !name.isEmpty {
                            existing.name = name
                        }
                        if let args = function["arguments"] as? String {
                            existing.arguments += args
                        }
                    }
                    toolCallsByIndex[index] = existing
                }
            }
        }

        let toolCalls = toolCallsByIndex.keys.sorted().compactMap { index -> LLMToolCall? in
            guard let entry = toolCallsByIndex[index], !entry.name.isEmpty else { return nil }
            let id = entry.id.isEmpty ? "call_\(index)" : entry.id
            return LLMToolCall(id: id, name: entry.name, arguments: entry.arguments.isEmpty ? "{}" : entry.arguments)
        }

        return LLMCompletionResult(
            content: accumulatedContent.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            reasoning: accumulatedReasoning.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            toolCalls: toolCalls,
            usage: streamUsage
        )
    }

    private func parseCompletionResult(from data: Data) throws -> LLMCompletionResult {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any]
        else {
            throw LLMServiceError.invalidResponse
        }

        let content = message["content"] as? String
        let reasoning = message["reasoning_content"] as? String
            ?? message["reasoning"] as? String

        var toolCalls: [LLMToolCall] = []
        if let rawCalls = message["tool_calls"] as? [[String: Any]] {
            for (index, call) in rawCalls.enumerated() {
                if let function = call["function"] as? [String: Any],
                   let name = function["name"] as? String {
                    let id = (call["id"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "call_\(index)"
                    let arguments = function["arguments"] as? String ?? "{}"
                    toolCalls.append(LLMToolCall(id: id, name: name, arguments: arguments))
                }
            }
        }

        return LLMCompletionResult(
            content: content?.trimmingCharacters(in: .whitespacesAndNewlines),
            reasoning: reasoning?.trimmingCharacters(in: .whitespacesAndNewlines),
            toolCalls: toolCalls,
            usage: parseUsage(from: json)
        )
    }

    private func parseUsage(from json: [String: Any]) -> LLMTokenUsage {
        guard let usage = json["usage"] as? [String: Any] else { return .zero }
        let prompt = usage["prompt_tokens"] as? Int ?? 0
        let completion = usage["completion_tokens"] as? Int ?? 0
        if prompt == 0, completion == 0 {
            if let total = usage["total_tokens"] as? Int, total > 0 {
                return LLMTokenUsage(promptTokens: total, completionTokens: 0)
            }
            return .zero
        }
        return LLMTokenUsage(promptTokens: prompt, completionTokens: completion)
    }

    func chat(
        prompt: String,
        history: [ChatMessage],
        configuration: LLMConfiguration,
        systemPrompt: String,
        maxTokens: Int? = nil,
        onEvent: ((LLMStreamEvent) -> Void)? = nil
    ) async throws -> String {
        let configuration = await preparedConfiguration(configuration)
        if configuration.provider.requiresAPIKey && configuration.apiKey.isEmpty {
            throw LLMServiceError.missingAPIKey(provider: configuration.provider)
        }

        let trimmedBaseURL = configuration.baseURL
        guard let url = URL(string: trimmedBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions") else {
            throw LLMServiceError.invalidURL
        }

        var messages: [[String: String]] = [
            [
                "role": "system",
                "content": systemPrompt,
            ],
        ]

        for item in history {
            messages.append([
                "role": item.role.rawValue,
                "content": item.content,
            ])
        }

        messages.append([
            "role": "user",
            "content": prompt,
        ])

        var payload: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "temperature": 0.3,
            "stream": onEvent != nil,
        ]
        if let maxTokens {
            payload["max_tokens"] = maxTokens
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorizationHeader(to: &request, apiKey: configuration.apiKey)
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        if onEvent != nil {
            return try await streamChat(
                request: request,
                provider: configuration.provider,
                baseURL: configuration.baseURL,
                onEvent: onEvent!
            )
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMServiceError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            var message = parseErrorMessage(from: data, provider: configuration.provider)
                ?? "请求失败（HTTP \(httpResponse.statusCode)）"
            if configuration.provider == .qwen {
                message = QwenBailianConfig.enrichError(message, baseURL: configuration.baseURL)
            } else if configuration.provider == .ollama {
                message = OllamaConfig.enrichError(
                    message,
                    host: OllamaConfig.resolvedHost(baseURL: configuration.baseURL)
                )
            }
            throw LLMServiceError.apiError(message, provider: configuration.provider)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any],
            let text = extractAssistantText(from: message)
        else {
            throw LLMServiceError.invalidResponse
        }

        return text
    }

    private func streamChat(
        request: URLRequest,
        provider: LLMProvider,
        baseURL: String,
        onEvent: @escaping (LLMStreamEvent) -> Void
    ) async throws -> String {
        cancelInFlightNetwork()

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMServiceError.invalidResponse
        }

        if !(200 ... 299).contains(httpResponse.statusCode) {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            var message = parseErrorMessage(from: errorData, provider: provider)
                ?? "请求失败（HTTP \(httpResponse.statusCode)）"
            if provider == .qwen {
                message = QwenBailianConfig.enrichError(message, baseURL: baseURL)
            } else if provider == .ollama {
                message = OllamaConfig.enrichError(message, host: OllamaConfig.resolvedHost(baseURL: baseURL))
            }
            throw LLMServiceError.apiError(message, provider: provider)
        }

        var accumulated = ""
        for try await line in bytes.lines {
            try Task.checkCancellation()

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("data:") else { continue }

            let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { continue }

            guard
                let jsonData = payload.data(using: .utf8),
                let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let first = choices.first,
                let delta = first["delta"] as? [String: Any]
            else {
                continue
            }

            let piece = streamTextPiece(from: delta)
            guard !piece.isEmpty else { continue }

            accumulated += piece
            onEvent(.textDelta(piece))
        }

        let text = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        onEvent(.done(text: text))
        return text
    }

    private func extractAssistantText(from message: [String: Any]) -> String? {
        if let content = message["content"] as? String {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if let reasoning = message["reasoning_content"] as? String ?? message["reasoning"] as? String {
            let trimmed = reasoning.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    private func streamTextPiece(from delta: [String: Any]) -> String {
        if let content = delta["content"] as? String, !content.isEmpty {
            return content
        }
        if let reasoning = delta["reasoning_content"] as? String ?? delta["reasoning"] as? String,
           !reasoning.isEmpty {
            return reasoning
        }
        return ""
    }

    private func applyAuthorizationHeader(to request: inout URLRequest, apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
    }

    private func parseErrorMessage(from data: Data, provider: LLMProvider) -> String? {
        if provider == .ollama {
            return OllamaConfig.parseAPIErrorMessage(from: data)
        }
        if provider == .qwen {
            return QwenBailianConfig.parseAPIErrorMessage(from: data)
        }
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = json["error"] as? [String: Any],
            let message = error["message"] as? String
        else {
            return String(data: data, encoding: .utf8)
        }
        return message
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

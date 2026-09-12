import Foundation

struct LLMToolCall: Equatable {
    let id: String
    let name: String
    let arguments: String
}

struct LLMCompletionResult {
    let content: String?
    let reasoning: String?
    let toolCalls: [LLMToolCall]
    let usage: LLMTokenUsage
}

/// LLM API evolution agent: OpenAI-compatible tool-calling loop with local sandboxed execution.
final class LLMEvolutionAgent {
    private let llmService = LLMService()
    private let maxIterationsDefault = 24

    func cancel() {
        llmService.cancel()
    }

    func run(
        prompt: String,
        history: [ChatMessage],
        configuration: LLMConfiguration,
        projectRoot: URL,
        allowMutations: Bool = true,
        maxIterations: Int? = nil,
        onEvent: (@Sendable (CursorStreamEvent) -> Void)? = nil,
        onUsage: (@Sendable (LLMTokenUsage) -> Void)? = nil,
        onContextTokens: (@Sendable (Int) -> Void)? = nil
    ) async throws -> (text: String, thinking: String?, usage: LLMTokenUsage) {
        let configuration = await resolvedConfiguration(configuration)
        var messages = buildMessages(prompt: prompt, history: history)
        let tools = EvolutionLocalTools.openAIToolDefinitions(allowMutations: allowMutations)
        var accumulatedThinking = ""
        var accumulatedText = ""
        var iteration = 0
        let iterationLimit = maxIterations ?? maxIterationsDefault
        var totalUsage = LLMTokenUsage.zero
        let tokenLimit = ModelTokenLimits.limit(forLLMModel: configuration.model, provider: configuration.provider)

        if configuration.provider == .ollama {
            let supportsTools = await OllamaConfig.modelSupportsTools(
                baseURL: configuration.baseURL,
                model: configuration.model,
                apiKey: configuration.apiKey
            )
            if !supportsTools {
                onEvent?(.statusUpdate("当前 Ollama 模型不支持工具调用，将以文字方案模式回复（无法自动改文件）。可换 llama3.1、qwen2.5 等支持工具的模型。"))
            }
        }

        while iteration < iterationLimit {
            try Task.checkCancellation()
            iteration += 1

            let estimatedPrompt = TokenEstimator.estimate(messages: messages)
            onContextTokens?(estimatedPrompt)
            let estimatedRequest = estimatedPrompt + EvolutionTokenCalculator.completionReserveTokens
            if estimatedRequest >= tokenLimit {
                throw LLMServiceError.contextWindowExceeded(
                    used: estimatedRequest,
                    limit: tokenLimit,
                    model: configuration.model
                )
            }

            onEvent?(.statusUpdate("第 \(iteration)/\(iterationLimit) 轮 · 等待大模型响应…"))

            let completion = try await llmService.completeWithTools(
                messages: messages,
                tools: tools,
                configuration: configuration,
                streamPartial: { reasoningDelta, contentDelta in
                    if let reasoningDelta, !reasoningDelta.isEmpty {
                        accumulatedThinking += reasoningDelta
                        onEvent?(.thinkingDelta(reasoningDelta))
                    }
                    if let contentDelta, !contentDelta.isEmpty {
                        accumulatedText += contentDelta
                        onEvent?(.textDelta(contentDelta))
                    }
                }
            )

            if completion.usage.totalTokens > 0 {
                totalUsage += completion.usage
                onUsage?(completion.usage)
            } else {
                let roundEstimate = LLMTokenUsage(
                    promptTokens: estimatedPrompt,
                    completionTokens: TokenEstimator.estimate(completion.content ?? "")
                        + TokenEstimator.estimate(completion.reasoning ?? "")
                )
                totalUsage += roundEstimate
                onUsage?(roundEstimate)
            }

            if let reasoning = completion.reasoning?.trimmingCharacters(in: .whitespacesAndNewlines),
               !reasoning.isEmpty {
                let delta = reasoningHasPrefix(accumulatedThinking, reasoning)
                    ? String(reasoning.dropFirst(accumulatedThinking.count))
                    : reasoning
                if !delta.isEmpty {
                    accumulatedThinking += delta
                    onEvent?(.thinkingDelta(delta))
                } else if accumulatedThinking.isEmpty {
                    accumulatedThinking = reasoning
                }
            }

            if completion.toolCalls.isEmpty {
                if let content = completion.content?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !content.isEmpty {
                    let delta = contentHasPrefix(accumulatedText, content)
                        ? String(content.dropFirst(accumulatedText.count))
                        : content
                    if !delta.isEmpty {
                        accumulatedText += delta
                        onEvent?(.textDelta(delta))
                    } else if accumulatedText.isEmpty {
                        accumulatedText = content
                        onEvent?(.textDelta(content))
                    }
                }

                let finalText = accumulatedText.isEmpty
                    ? (completion.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    : accumulatedText
                let thinking = accumulatedThinking.isEmpty ? nil : accumulatedThinking
                onEvent?(.done(text: finalText, thinking: thinking))
                onEvent?(.statusUpdate(""))

                guard !finalText.isEmpty || thinking != nil else {
                    throw toolSupportError(for: configuration)
                }
                return (text: finalText, thinking: thinking, usage: totalUsage)
            }

            onEvent?(.statusUpdate("第 \(iteration)/\(iterationLimit) 轮 · 执行 \(completion.toolCalls.count) 个工具…"))

            if let content = completion.content, !content.isEmpty {
                if !contentHasPrefix(accumulatedText, content) {
                    accumulatedText += content
                    onEvent?(.textDelta(content))
                } else if accumulatedText.isEmpty {
                    accumulatedText = content
                    onEvent?(.textDelta(content))
                }
            }

            let serializedToolCalls: [[String: Any]] = completion.toolCalls.map { call in
                [
                    "id": call.id,
                    "type": "function",
                    "function": [
                        "name": call.name,
                        "arguments": call.arguments,
                    ] as [String: Any],
                ]
            }
            let assistantMessage: [String: Any]
            if configuration.provider == .qwen {
                assistantMessage = QwenBailianConfig.assistantToolCallMessage(
                    content: completion.content,
                    reasoning: completion.reasoning,
                    toolCalls: serializedToolCalls
                )
            } else {
                var message: [String: Any] = ["role": "assistant"]
                let trimmedContent = completion.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if trimmedContent.isEmpty, !serializedToolCalls.isEmpty {
                    message["content"] = NSNull()
                } else {
                    message["content"] = trimmedContent
                }
                if let reasoning = completion.reasoning?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !reasoning.isEmpty {
                    message["reasoning_content"] = reasoning
                }
                message["tool_calls"] = serializedToolCalls
                assistantMessage = message
            }
            messages.append(assistantMessage)
            onContextTokens?(TokenEstimator.estimate(messages: messages))

            let toolOutcomes = await executeToolCalls(
                completion.toolCalls,
                projectRoot: projectRoot,
                allowMutations: allowMutations,
                onEvent: onEvent
            )

            for outcome in toolOutcomes {
                messages.append([
                    "role": "tool",
                    "tool_call_id": outcome.call.id,
                    "content": outcome.failed ? "错误：\(outcome.toolResult)" : outcome.toolResult,
                ])
            }
            onContextTokens?(TokenEstimator.estimate(messages: messages))
        }

        throw LLMServiceError.apiError(
            "进化 Agent 达到最大工具轮次（\(iterationLimit)），请缩小任务范围后重试。",
            provider: configuration.provider
        )
    }

    private func resolvedConfiguration(_ configuration: LLMConfiguration) async -> LLMConfiguration {
        if configuration.provider == .qwen {
            return QwenBailianConfig.preparedConfiguration(configuration)
        }
        guard configuration.provider == .ollama else { return configuration }
        let baseURL = OllamaConfig.normalizedOpenAIBaseURL(configuration.baseURL)
        let apiKey = OllamaConfig.resolveAPIKey(stored: configuration.apiKey)
        let model = await OllamaConfig.resolveModelForRequest(
            configuration.model,
            baseURL: baseURL,
            apiKey: apiKey
        )
        return LLMConfiguration(provider: .ollama, baseURL: baseURL, model: model, apiKey: apiKey)
    }

    private func buildMessages(prompt: String, history: [ChatMessage]) -> [[String: Any]] {
        var messages: [[String: Any]] = [
            [
                "role": "system",
                "content": Self.systemPrompt,
            ],
        ]

        let filteredHistory = history.filter { message in
            guard message.role == .assistant else { return true }
            return !BookL10nMarkers.isEvolutionWelcome(message.content)
        }

        for item in filteredHistory {
            messages.append([
                "role": item.role.rawValue,
                "content": historyContent(for: item),
            ])
        }

        messages.append([
            "role": "user",
            "content": prompt,
        ])
        return messages
    }

    private struct ToolRunOutcome {
        let call: LLMToolCall
        let detail: String?
        let toolResult: String
        let failed: Bool
    }

    private func executeToolCalls(
        _ calls: [LLMToolCall],
        projectRoot: URL,
        allowMutations: Bool,
        onEvent: (@Sendable (CursorStreamEvent) -> Void)?
    ) async -> [ToolRunOutcome] {
        guard !calls.isEmpty else { return [] }

        for call in calls {
            let detail = toolDetail(name: call.name, argumentsJSON: call.arguments)
            onEvent?(.toolUpdate(
                name: call.name,
                status: "running",
                callId: call.id,
                detail: detail,
                result: nil,
                error: nil
            ))
        }

        return await withTaskGroup(of: (Int, ToolRunOutcome).self) { group in
            for (index, call) in calls.enumerated() {
                group.addTask {
                    let detail = self.toolDetail(name: call.name, argumentsJSON: call.arguments)
                    let toolResult: String
                    let failed: Bool
                    switch EvolutionLocalTools.execute(
                        name: call.name,
                        argumentsJSON: call.arguments,
                        projectRoot: projectRoot,
                        allowMutations: allowMutations
                    ) {
                    case .success(let output):
                        toolResult = output
                        failed = false
                        onEvent?(.toolUpdate(
                            name: call.name,
                            status: "completed",
                            callId: call.id,
                            detail: detail,
                            result: self.summarizeToolResult(output),
                            error: nil
                        ))
                    case .failure(let error):
                        toolResult = error.localizedDescription
                        failed = true
                        onEvent?(.toolUpdate(
                            name: call.name,
                            status: "failed",
                            callId: call.id,
                            detail: detail,
                            result: nil,
                            error: toolResult
                        ))
                    }
                    return (
                        index,
                        ToolRunOutcome(call: call, detail: detail, toolResult: toolResult, failed: failed)
                    )
                }
            }

            var indexed: [(Int, ToolRunOutcome)] = []
            for await item in group {
                indexed.append(item)
            }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    private func historyContent(for message: ChatMessage) -> String {
        guard message.role == .assistant else { return message.content }

        var sections: [String] = []
        if let steps = message.toolSteps, !steps.isEmpty {
            sections.append(compactToolTrace(steps))
        }
        if let thinking = message.thinking?.trimmingCharacters(in: .whitespacesAndNewlines),
           !thinking.isEmpty {
            let excerpt = thinking.count > 2_400
                ? String(thinking.prefix(2_397)) + "…"
                : thinking
            sections.append("【上轮思考摘要】\n\(excerpt)")
        }
        let body = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !body.isEmpty {
            sections.append(body)
        }
        return sections.isEmpty ? message.content : sections.joined(separator: "\n\n")
    }

    private func compactToolTrace(_ steps: [ExecutionStep]) -> String {
        let lines = steps.map { step -> String in
            var parts = [EvolutionToolLabels.localizedToolName(step.name)]
            if let detail = step.detail?.components(separatedBy: "\n").first,
               !detail.isEmpty {
                parts.append(detail)
            }
            parts.append(step.status == .completed ? "✓" : (step.status == .failed ? "✗" : "…"))
            if let result = step.resultSummary, !result.isEmpty {
                parts.append("→ \(String(result.prefix(120)))")
            }
            if let error = step.errorMessage, !error.isEmpty {
                parts.append("! \(String(error.prefix(120)))")
            }
            return parts.joined(separator: " ")
        }
        return "【上轮 Agent 工具摘要】\n\(lines.joined(separator: "\n"))"
    }

    private func toolDetail(name: String, argumentsJSON: String) -> String? {
        guard let data = argumentsJSON.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return argumentsJSON.nilIfEmpty
        }

        var summaryParts: [String] = []

        switch name.lowercased() {
        case "read", "read_file", "write", "write_file", "edit", "strreplace", "search_replace":
            if let path = args["path"] as? String {
                summaryParts.append(path)
            }
        case "grep":
            if let pattern = args["pattern"] as? String {
                summaryParts.append(pattern)
                if let path = args["path"] as? String { summaryParts.append(path) }
            }
        case "glob", "glob_file_search":
            if let pattern = args["pattern"] as? String {
                summaryParts.append(pattern)
            }
        case "shell", "run_terminal_cmd":
            if let command = args["command"] as? String {
                summaryParts.append(command)
            }
        default:
            break
        }

        let formattedArgs = formatToolArguments(args)
        if summaryParts.isEmpty {
            return formattedArgs
        }
        return summaryParts.joined(separator: " · ") + "\n" + formattedArgs
    }

    private func formatToolArguments(_ args: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: args, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        if text.count > 2_000 {
            return String(text.prefix(1_997)) + "…"
        }
        return text
    }

    private func summarizeToolResult(_ output: String) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 400 { return trimmed }
        return String(trimmed.prefix(397)) + "…"
    }

    private func reasoningHasPrefix(_ accumulated: String, _ full: String) -> Bool {
        full.hasPrefix(accumulated)
    }

    private func contentHasPrefix(_ accumulated: String, _ full: String) -> Bool {
        full.hasPrefix(accumulated)
    }

    private func toolSupportError(for configuration: LLMConfiguration) -> LLMServiceError {
        let hint: String
        switch configuration.provider {
        case .ollama:
            hint = "当前 Ollama 模型可能不支持 tool_calls。请改用 qwen2.5、llama3.1 等支持工具的模型，或切换到 OpenAI / DeepSeek 等云端提供商。"
        case .openAI, .deepSeek, .moonshot, .qwen, .zhipu:
            hint = "大模型未返回有效内容或工具调用。请确认模型支持 function calling，或缩小任务后重试。"
        case .custom:
            hint = "大模型未返回有效内容。请确认 API 兼容 OpenAI tools/tool_calls 格式。"
        }
        return LLMServiceError.apiError(hint, provider: configuration.provider)
    }

    private static let systemPrompt = """
    \(EvolutionAssistant.systemPrompt)

    【大模型进化模式 — 本地工具（对齐 Cursor Agent）】
    你已通过 tool_calls 调用本地沙箱工具（read / grep / glob / edit / write / shell），在 ai-book 源码目录内实际读写与验证。
    - 改码前先用 read/grep/glob 探索；改码用 edit 或 write；改码后优先 shell 运行 `swift build` 或 `scripts/build-and-install.sh` 验证
    - 同一轮可并行发起多个工具调用；不要只描述计划而不调用工具
    - 最小必要改动，保持 BookTheme 书籍风格；展示思考与中间过程
    - 最终回复须含一行完成摘要：「编号、已完成：…」
    """
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

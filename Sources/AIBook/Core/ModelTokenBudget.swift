import Foundation

/// Token counts reported by OpenAI-compatible APIs.
struct LLMTokenUsage: Equatable {
    let promptTokens: Int
    let completionTokens: Int

    var totalTokens: Int { promptTokens + completionTokens }

    static let zero = LLMTokenUsage(promptTokens: 0, completionTokens: 0)

    static func + (lhs: LLMTokenUsage, rhs: LLMTokenUsage) -> LLMTokenUsage {
        LLMTokenUsage(
            promptTokens: lhs.promptTokens + rhs.promptTokens,
            completionTokens: lhs.completionTokens + rhs.completionTokens
        )
    }

    static func += (lhs: inout LLMTokenUsage, rhs: LLMTokenUsage) {
        lhs = lhs + rhs
    }
}

/// Real-time token budget for the current model (next request context + remaining vs context window).
struct ModelTokenBudget: Equatable {
    let contextTokens: Int
    let limitTokens: Int
    let sessionConsumedTokens: Int
    let completionReserveTokens: Int
    let modelLabel: String

    /// The amount that must fit in the model window before the next request is sent.
    var usedTokens: Int { contextTokens + completionReserveTokens }
    var remainingTokens: Int { max(0, limitTokens - usedTokens) }
    var percentage: Double {
        guard limitTokens > 0 else { return 0 }
        return Double(usedTokens) / Double(limitTokens) * 100.0
    }
    var progressPercentage: Double { min(percentage, 100.0) }
    var isOverLimit: Bool { usedTokens >= limitTokens }
    var isNearLimit: Bool { percentage >= 90 }

    var formattedUsed: String { TokenDisplay.format(usedTokens) }
    var formattedLimit: String { TokenDisplay.format(limitTokens) }
    var formattedRemaining: String { TokenDisplay.format(remainingTokens) }
    var formattedContext: String { TokenDisplay.format(contextTokens) }
    var formattedSessionConsumed: String { TokenDisplay.format(sessionConsumedTokens) }
    var formattedCompletionReserve: String { TokenDisplay.format(completionReserveTokens) }
    var formattedPercentage: String { "\(Int(percentage.rounded()))%" }

    func blockMessage(for action: String) -> String? {
        guard isOverLimit else { return nil }
        return """
        当前模型 \(modelLabel) token 额度已达上限（已用 \(formattedUsed)/\(formattedLimit)，剩余 \(formattedRemaining)），无法\(action)。
        请清空进化对话、缩短左页命令笔记，或换用更大上下文的模型后重试。
        """
    }
}

enum TokenDisplay {
    static func format(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000.0)
        }
        if tokens >= 1000 {
            return String(format: "%.1fk", Double(tokens) / 1000.0)
        }
        return "\(tokens)"
    }
}

/// Rough token estimation when the API does not return usage (mixed Chinese / code).
enum TokenEstimator {
    static func estimate(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        let scalars = trimmed.unicodeScalars
        var cjkCount = 0
        for scalar in scalars {
            switch scalar.value {
            case 0x4E00 ... 0x9FFF, 0x3400 ... 0x4DBF:
                cjkCount += 1
            default:
                break
            }
        }
        let total = trimmed.count
        let cjkRatio = total > 0 ? Double(cjkCount) / Double(total) : 0
        // Chinese-heavy text ≈ 1.6 chars/token; Latin/code ≈ 4 chars/token
        let charsPerToken = 4.0 * (1 - cjkRatio * 0.6) + 1.6 * (cjkRatio * 0.6)
        return max(1, Int(ceil(Double(total) / charsPerToken)))
    }

    static func estimate(messages: [[String: Any]]) -> Int {
        messages.reduce(0) { partial, message in
            var size = partial
            if let content = message["content"] as? String {
                size += estimate(content)
            } else if let parts = message["content"] as? [[String: Any]] {
                for part in parts {
                    if let text = part["text"] as? String {
                        size += estimate(text)
                    }
                }
            }
            if let toolCalls = message["tool_calls"] as? [[String: Any]] {
                for call in toolCalls {
                    if let function = call["function"] as? [String: Any],
                       let args = function["arguments"] as? String {
                        size += estimate(args)
                    }
                    if let name = (call["function"] as? [String: Any])?["name"] as? String {
                        size += estimate(name)
                    }
                }
            }
            if let role = message["role"] as? String {
                size += estimate(role)
            }
            return size
        }
    }
}

enum ModelTokenLimits {
    static func limit(forCursorModel model: String) -> Int {
        let lower = model.lowercased()
        if lower.contains("composer") { return 200_000 }
        if lower.contains("auto-smart") { return 200_000 }
        if lower.contains("claude") { return 200_000 }
        if lower.contains("gpt-4") { return 128_000 }
        if lower == "auto" { return 128_000 }
        return 128_000
    }

    static func limit(forLLMModel model: String, provider: LLMProvider) -> Int {
        let lower = model.lowercased()
        if lower.contains("1m") || lower.contains("1000k") { return 1_000_000 }
        if lower.contains("128k") || lower.contains("131072") { return 131_072 }
        if lower.contains("64k") || lower.contains("65536") { return 65_536 }
        if lower.contains("32k") || lower.contains("32768") { return 32_768 }
        if lower.contains("16k") { return 16_384 }
        if lower.contains("8k") { return 8_192 }
        if lower.contains("qwen") { return 131_072 }
        if lower.contains("deepseek") { return 64_000 }
        if lower.contains("gpt-4") { return 128_000 }
        if lower.contains("gpt-3.5") { return 16_384 }
        if lower.contains("llama3") || lower.contains("llama-3") { return 128_000 }
        if provider == .ollama { return 32_768 }
        return 64_000
    }

    static func cursorModelLabel(_ model: String) -> String {
        CursorModelOption(rawValue: model)?.label ?? model
    }
}

enum EvolutionTokenCalculator {
    /// Reserve output room so the request is blocked before the model window is completely full.
    static let completionReserveTokens = 2_048

    /// Estimates tokens for the visible evolution chat + optional outbound prompt.
    static func estimateContext(
        messages: [ChatMessage],
        input: String,
        streamingThinking: String,
        streamingResponse: String,
        toolSteps: [ExecutionStep],
        additionalPrompt: String? = nil
    ) -> Int {
        var total = 0

        for message in messages {
            total += TokenEstimator.estimate(message.content)
            if let thinking = message.thinking {
                total += TokenEstimator.estimate(thinking)
            }
            if let steps = message.toolSteps {
                for step in steps {
                    total += TokenEstimator.estimate(step.name)
                    if let detail = step.detail { total += TokenEstimator.estimate(detail) }
                    if let result = step.resultSummary { total += TokenEstimator.estimate(result) }
                    if let error = step.errorMessage { total += TokenEstimator.estimate(error) }
                }
            }
        }

        total += TokenEstimator.estimate(input)
        total += TokenEstimator.estimate(streamingThinking)
        total += TokenEstimator.estimate(streamingResponse)

        for step in toolSteps {
            total += TokenEstimator.estimate(step.name)
            if let detail = step.detail { total += TokenEstimator.estimate(detail) }
            if let result = step.resultSummary { total += TokenEstimator.estimate(result) }
        }

        if let additionalPrompt {
            total += TokenEstimator.estimate(additionalPrompt)
        }

        // System prompt + tool definitions overhead for LLM agent mode
        total += 4_800
        return total
    }

    static func budget(
        sessionConsumedTokens: Int,
        agentLiveContextTokens: Int,
        messages: [ChatMessage],
        input: String,
        streamingThinking: String,
        streamingResponse: String,
        toolSteps: [ExecutionStep],
        additionalPrompt: String? = nil,
        usesCursor: Bool,
        cursorModel: String,
        llmModel: String,
        llmProvider: LLMProvider
    ) -> ModelTokenBudget {
        let limit: Int
        let label: String
        if usesCursor {
            limit = ModelTokenLimits.limit(forCursorModel: cursorModel)
            label = ModelTokenLimits.cursorModelLabel(cursorModel)
        } else {
            limit = ModelTokenLimits.limit(forLLMModel: llmModel, provider: llmProvider)
            label = llmModel.isEmpty ? llmProvider.rawValue : llmModel
        }

        let visibleEstimate = estimateContext(
            messages: messages,
            input: input,
            streamingThinking: streamingThinking,
            streamingResponse: streamingResponse,
            toolSteps: toolSteps,
            additionalPrompt: additionalPrompt
        )
        let contextTokens = max(visibleEstimate, agentLiveContextTokens)

        return ModelTokenBudget(
            contextTokens: contextTokens,
            limitTokens: limit,
            sessionConsumedTokens: sessionConsumedTokens,
            completionReserveTokens: completionReserveTokens,
            modelLabel: label
        )
    }
}

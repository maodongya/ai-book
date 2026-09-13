import Foundation

/// OpenAI 兼容接口回报的 token 用量。只有 prompt / completion，总数现算。
struct LLMTokenUsage: Equatable {
    /// 请求（含历史）消耗。
    let promptTokens: Int
    /// 模型输出消耗。
    let completionTokens: Int

    /// prompt + completion，给进度条用。
    var totalTokens: Int { promptTokens + completionTokens }

    /// 还没有任何回报时的零值，避免 optional。
    static let zero = LLMTokenUsage(promptTokens: 0, completionTokens: 0)

    /// 两段用量相加，会话累计用。
    static func + (lhs: LLMTokenUsage, rhs: LLMTokenUsage) -> LLMTokenUsage {
        LLMTokenUsage(
            promptTokens: lhs.promptTokens + rhs.promptTokens, // 分别加，便于之后拆开显示
            completionTokens: lhs.completionTokens + rhs.completionTokens
        )
    }

    /// 累加到左侧，会话里原地更新。
    static func += (lhs: inout LLMTokenUsage, rhs: LLMTokenUsage) {
        lhs = lhs + rhs // 复用 +，不写第二套加法
    }
}

/// 当前模型的实时额度：下次请求要装进窗口的量 + 相对窗口还剩多少。
struct ModelTokenBudget: Equatable {
    /// 估计或实测的上下文占用（不含预留下限）。
    let contextTokens: Int
    /// 模型窗口上限。
    let limitTokens: Int
    /// 本会话 API 已回报的累计消耗，给「已经花了多少」看，不参与是否超限。
    let sessionConsumedTokens: Int
    /// 为输出预留的 token，避免窗满了才拦。
    let completionReserveTokens: Int
    /// 给用户看的模型名。
    let modelLabel: String

    /// 下次请求必须装进窗口的量 = 上下文 + 输出预留。
    var usedTokens: Int { contextTokens + completionReserveTokens }
    /// 窗口还剩多少，不低于 0。
    var remainingTokens: Int { max(0, limitTokens - usedTokens) }
    /// 占用百分比，上限为 0 时当 0，避免除零。
    var percentage: Double {
        guard limitTokens > 0 else { return 0 }
        return Double(usedTokens) / Double(limitTokens) * 100.0
    }
    /// 进度条用，封顶 100，超限仍画满。
    var progressPercentage: Double { min(percentage, 100.0) }
    /// 已无法再发下一次请求。
    var isOverLimit: Bool { usedTokens >= limitTokens }
    /// 接近上限（≥90%），UI 可提前警告。
    var isNearLimit: Bool { percentage >= 90 }

    var formattedUsed: String { TokenDisplay.format(usedTokens) } // 已用，给文案插值
    var formattedLimit: String { TokenDisplay.format(limitTokens) }
    var formattedRemaining: String { TokenDisplay.format(remainingTokens) }
    var formattedContext: String { TokenDisplay.format(contextTokens) }
    var formattedSessionConsumed: String { TokenDisplay.format(sessionConsumedTokens) }
    var formattedCompletionReserve: String { TokenDisplay.format(completionReserveTokens) }
    var formattedPercentage: String { "\(Int(percentage.rounded()))%" } // 四舍五入到整数百分比

    /// 超限时返回拦截文案；未超限返回 nil，调用方直接放行。
    func blockMessage(for action: String) -> String? {
        guard isOverLimit else { return nil }
        return """
        当前模型 \(modelLabel) token 额度已达上限（已用 \(formattedUsed)/\(formattedLimit)，剩余 \(formattedRemaining)），无法\(action)。
        请清空进化对话、缩短左页命令笔记，或换用更大上下文的模型后重试。
        """ // action 由调用方填「发送」「分析」等，复用同一句
    }
}

/// token 数量的短显示：≥100万用 M，≥1000 用 k。
enum TokenDisplay {
    /// 进度条和拦截文案共用，改格式只改这里。
    static func format(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000.0) // 百万级窗口
        }
        if tokens >= 1000 {
            return String(format: "%.1fk", Double(tokens) / 1000.0)
        }
        return "\(tokens)" // 三位数以内不缩写，避免 0.2k
    }
}

/// API 没回 usage 时的粗估（中英/代码混排）。只估数量，不当事后对账。
enum TokenEstimator {
    /// 单段文本：CJK 多则按更少字/token 估。
    static func estimate(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 } // 空白不当 1 token，避免空气泡抬高预算

        let scalars = trimmed.unicodeScalars
        var cjkCount = 0
        for scalar in scalars {
            switch scalar.value {
            case 0x4E00 ... 0x9FFF, 0x3400 ... 0x4DBF:
                cjkCount += 1 // 基本汉字 + 扩展 A，足够估中文密度
            default:
                break
            }
        }
        let total = trimmed.count
        let cjkRatio = total > 0 ? Double(cjkCount) / Double(total) : 0
        let charsPerToken = 4.0 * (1 - cjkRatio * 0.6) + 1.6 * (cjkRatio * 0.6) // 中文密约 1.6 字/token，拉丁/代码约 4，按占比插
        return max(1, Int(ceil(Double(total) / charsPerToken))) // 非空文本至少 1
    }

    /// 估计 OpenAI 消息数组（content / tool_calls / role）。
    static func estimate(messages: [[String: Any]]) -> Int {
        messages.reduce(0) { partial, message in
            var size = partial
            if let content = message["content"] as? String {
                size += estimate(content) // 普通字符串内容
            } else if let parts = message["content"] as? [[String: Any]] {
                for part in parts {
                    if let text = part["text"] as? String {
                        size += estimate(text) // 多模态里的文本块，图不估
                    }
                }
            }
            if let toolCalls = message["tool_calls"] as? [[String: Any]] {
                for call in toolCalls {
                    if let function = call["function"] as? [String: Any],
                       let args = function["arguments"] as? String {
                        size += estimate(args) // 工具参数往往很长
                    }
                    if let name = (call["function"] as? [String: Any])?["name"] as? String {
                        size += estimate(name)
                    }
                }
            }
            if let role = message["role"] as? String {
                size += estimate(role) // role 本身也占一点
            }
            return size
        }
    }
}

/// 按模型名/供应商猜窗口大小。名字里带 128k 等优先，否则给保守默认。
enum ModelTokenLimits {
    /// Cursor 侧模型窗口。
    static func limit(forCursorModel model: String) -> Int {
        let lower = model.lowercased()
        if lower.contains("composer") { return 200_000 }
        if lower.contains("auto-smart") { return 200_000 }
        if lower.contains("claude") { return 200_000 }
        if lower.contains("gpt-4") { return 128_000 }
        if lower == "auto" { return 128_000 }
        return 128_000 // 未知 Cursor 模型按 128k，避免估太大放行后被打回
    }

    /// 外部 LLM 窗口：先看名字里的容量标记，再按家族，最后按供应商。
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
        if provider == .ollama { return 32_768 } // 本地默认偏小
        return 64_000 // 未点名的云模型给中等窗口
    }

    /// Cursor 模型的用户可见标签；未知 rawValue 原样显示。
    static func cursorModelLabel(_ model: String) -> String {
        CursorModelOption(rawValue: model)?.label ?? model
    }
}

/// 进化对话的上下文估算和额度组装。
enum EvolutionTokenCalculator {
    /// 为输出预留的房间，必须在窗完全满之前拦住请求。
    static let completionReserveTokens = 2_048

    /// 可见进化聊天 + 可选即将发出的提示，粗估 token。
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
            total += TokenEstimator.estimate(message.content) // 已落盘的气泡
            if let thinking = message.thinking {
                total += TokenEstimator.estimate(thinking) // 思考链也进上下文
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

        total += TokenEstimator.estimate(input) // 输入框里还没发出去的
        total += TokenEstimator.estimate(streamingThinking) // 正在流的思考
        total += TokenEstimator.estimate(streamingResponse) // 正在流的正文

        for step in toolSteps {
            total += TokenEstimator.estimate(step.name) // 尚未写入气泡的当前工具步
            if let detail = step.detail { total += TokenEstimator.estimate(detail) }
            if let result = step.resultSummary { total += TokenEstimator.estimate(result) }
        }

        if let additionalPrompt {
            total += TokenEstimator.estimate(additionalPrompt) // 左页命令笔记等额外提示
        }

        total += 4_800 // 系统提示+工具定义开销（agent 模式），改提示词要重测
        return total
    }

    /// 拼出当前进化会话的额度：取可见估算和 agent 实测上下文的较大值。
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
            limit = ModelTokenLimits.limit(forCursorModel: cursorModel) // Cursor 通道按 Cursor 模型估窗
            label = ModelTokenLimits.cursorModelLabel(cursorModel)
        } else {
            limit = ModelTokenLimits.limit(forLLMModel: llmModel, provider: llmProvider)
            label = llmModel.isEmpty ? llmProvider.rawValue : llmModel // 没填模型名时至少显示供应商
        }

        let visibleEstimate = estimateContext(
            messages: messages,
            input: input,
            streamingThinking: streamingThinking,
            streamingResponse: streamingResponse,
            toolSteps: toolSteps,
            additionalPrompt: additionalPrompt
        ) // 界面上看见的一切
        let contextTokens = max(visibleEstimate, agentLiveContextTokens) // 实测更大就信实测，避免低估放行

        return ModelTokenBudget(
            contextTokens: contextTokens,
            limitTokens: limit,
            sessionConsumedTokens: sessionConsumedTokens,
            completionReserveTokens: completionReserveTokens,
            modelLabel: label
        )
    }
}

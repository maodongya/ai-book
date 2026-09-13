import AIBookEvolution
import Foundation

@MainActor
/// 读书/进化消息的流式请求编排（LLM 与 Cursor）。
final class ReadingMessageOrchestrator {
    unowned var host: ReadingViewModel!  // 由 VM init 注入，生命周期跟宿主

    /// 清流式思考/正文/工具步骤，下一轮重填。
    func resetStreamingState() {
        host.streamingThinking = ""  // 清思考链，下一轮重填
        host.streamingResponse = ""  // 清正文流
        host.streamingToolStatus = ""  // 清顶栏工具文案
        host.streamingToolSteps = []  // 清步骤列表，避免串到下一次
        host.evolution.evolutionAgentContextTokens = 0  // 本轮 token 从 0 计
        host.evolution.showsExecutionTrace = false  // 默认不露执行轨迹，beginRun 再开
        host.assistant.readingAssistantActiveTask = nil  // 顶栏任务标清掉
    }


    /// 开跑：转圈、可停止，按需露执行轨迹。
    func beginRun(showsExecutionTrace: Bool) {
        host.isLoading = true  // 转圈开始
        host.isRunning = true  // 停止按钮可点
        host.suppressReplySpeech = false  // 本轮默认可读回复
        resetStreamingState()  // 清流，避免残字
        host.evolution.showsExecutionTrace = showsExecutionTrace  // 进化/分析才露工具步骤
    }


    /// 读书 LLM 增量：只拼正文。
    func handleLLMStreamEvent(_ event: LLMStreamEvent) {
        switch event {
        case .textDelta(let delta):  // 读书助手只拼正文
            if host.assistant.readingAssistantActiveTask == .translation {  // 翻译进弹出层
                host.translation.appendTranslationStreamPreview(delta)
            } else {
                host.streamingResponse += delta  // 增量追加，不整段替换
            }
        case .done, .error:  // 收尾在 Task 里处理，这里不改状态
            break  // 事件已消费
        }
    }


    /// Cursor 流：思考/工具/状态按轨迹开关收。
    func handleCursorStreamEvent(_ event: CursorStreamEvent) {
        switch event {
        case .thinkingDelta(let delta):  // 思考只在开了轨迹时显示
            guard host.evolution.showsExecutionTrace else { return }  // 关轨迹就不堆思考/工具
            host.streamingThinking += delta  // 思考增量
        case .textDelta(let delta):  // 读书助手只拼正文
            host.streamingResponse += delta  // 增量追加，不整段替换
        case .toolUpdate(let name, let status, let callId, let detail, let result, let error):  // 同 callId 合并，避免一步多条
            guard host.evolution.showsExecutionTrace else { return }  // 关轨迹就不堆思考/工具
            applyToolStepUpdate(  // 按 callId 或工具名收进列表
                name: name,
                status: status,
                callId: callId,
                detail: detail,
                result: result,
                error: error
            )
        case .statusUpdate(let status):  // 顶栏短状态
            guard host.evolution.showsExecutionTrace else { return }  // 关轨迹就不堆思考/工具
            host.streamingToolStatus = status  // 覆盖，不追加
        case .error(let message):  // 流上的错误先写 errorMessage
            host.errorMessage = message  // 顶栏
        case .done(let text, let thinking):  // 有的桥只在 done 给全文
            if host.assistant.readingAssistantActiveTask == .translation {  // 翻译不写讲解流
                if host.translation.translationStreamPreview.isEmpty, !text.isEmpty {
                    host.translation.translationStreamPreview = text
                }
            } else if host.streamingResponse.isEmpty, !text.isEmpty {  // 流里没拼到才用收尾全文
                host.streamingResponse = text  // 补正文
            }
            guard host.evolution.showsExecutionTrace else { return }  // 关轨迹就不堆思考/工具
            if host.streamingThinking.isEmpty, let thinking, !thinking.isEmpty {  // 思考同理
                host.streamingThinking = thinking  // 补思考链
            }
        }
    }


    /// 将 Cursor 工具调用事件合并进当前流式步骤列表，并刷新工具状态文案。
    func applyToolStepUpdate(
        name: String,
        status: String,
        callId: String?,
        detail: String?,
        result: String?,
        error: String?
    ) {
        let stepStatus: ExecutionStep.Status // 桥接 status 映射为 UI 步骤，completed/failed/其余当 running
        switch status {  // 只认 completed/failed/error，其余当 running
        case "completed":  // 成功收尾
            stepStatus = .completed  // 可写 completedAt
        case "failed", "error":  // 两种失败字都当 failed
            stepStatus = .failed  // 红字步骤
        default:  // started/running/未知都当进行中
            stepStatus = .running  // 不写 completedAt
        }

        let completionTime = stepStatus == .running ? nil : Date()  // 进行中没有结束时间

        if stepStatus == .running {  // 更新或追加 running
            if let callId, // 同一 callId 仍在跑：只更新 detail，避免重复追加
               let index = host.streamingToolSteps.lastIndex(where: { $0.callId == callId }) {  // 配对开始那条
                let existing = host.streamingToolSteps[index]  // 可能误配同名并发，总好过再插一条
                if existing.status == .running {  // 已结束的不回写成 running
                    if let detail, !detail.isEmpty {  // 空 detail 不覆盖已有说明
                        host.streamingToolSteps[index] = ExecutionStep(  // 收尾
                            id: existing.id,
                            callId: existing.callId,
                            name: name,
                            detail: detail,
                            status: .running,
                            startedAt: existing.startedAt
                        )
                    }
                    return  // finally 仍会清 isRunning
                }
            }
            host.streamingToolSteps.append( // 新工具调用，追加 running 步骤
                ExecutionStep(callId: callId, name: name, detail: detail, status: .running)  // startedAt 默认现在
            )
        } else if let callId,  // 结束事件：先按 callId
                  let index = host.streamingToolSteps.lastIndex(where: { $0.callId == callId }) {  // 配对开始那条
            let existing = host.streamingToolSteps[index] // 按 callId 收尾已有步骤
            host.streamingToolSteps[index] = ExecutionStep(  // 收尾
                id: existing.id,
                callId: existing.callId,
                name: existing.name,
                detail: detail ?? existing.detail,
                status: stepStatus,
                startedAt: existing.startedAt,
                completedAt: completionTime ?? existing.completedAt,
                resultSummary: result ?? existing.resultSummary,
                errorMessage: error ?? existing.errorMessage
            )
        } else if let index = host.streamingToolSteps.lastIndex(where: { $0.name == name && $0.status == .running }) {  // 没 callId 就按工具名碰最后一个 running
            let existing = host.streamingToolSteps[index] // 无 callId 时按工具名匹配最后一个 running
            host.streamingToolSteps[index] = ExecutionStep(  // 收尾
                id: existing.id,
                callId: existing.callId,
                name: existing.name,
                detail: detail ?? existing.detail,
                status: stepStatus,
                startedAt: existing.startedAt,
                completedAt: completionTime ?? existing.completedAt,
                resultSummary: result ?? existing.resultSummary,
                errorMessage: error ?? existing.errorMessage
            )
        } else {  // 讲解用模板历史
            host.streamingToolSteps.append( // 兜底：直接追加一条已结束步骤
                ExecutionStep(
                    callId: callId,
                    name: name,
                    detail: detail,
                    status: stepStatus,
                    completedAt: completionTime,
                    resultSummary: result,
                    errorMessage: error
                )
            )
        }

        host.streamingToolStatus = stepStatus == .running // 顶栏/气泡工具状态摘要
            ? BookL10n.format("vm.tool.running", EvolutionToolLabels.localizedToolName(name))  // 进行中：本地化工具名
            : BookL10n.format("vm.tool.done", EvolutionToolLabels.localizedToolName(name))  // 结束：同样本地化
    }


    /// 若当前流式步骤非空则返回副本，供写入 assistant 消息。
    func resolvedToolStepsForMessage() -> [ExecutionStep]? {
        host.streamingToolSteps.isEmpty ? nil : host.streamingToolSteps  // 空不写进消息，避免空数组占位
    }


    /// 统一入口：读书助手或进化/分析任务，拼历史、流式请求、写回对话与后续进化链。
    func sendMessage(
        _ prompt: String,
        displayText: String,
        isEvolution: Bool = false,
        evolutionCommandNumber: Int? = nil,
        speakReplyWhenDone: Bool = false,
        triggerEvolutionRebuild: Bool = false,
        evolutionRunKind: ReadingEvolutionRunKind = .none
    ) {
        let runKind = evolutionRunKind == .none // 未显式传入则按 isEvolution 推断讲解/进化
            ? (isEvolution ? ReadingEvolutionRunKind.evolution : .none)  // 旧调用只传了布尔
            : evolutionRunKind  // 分析/追问走显式值
        let settings = AppSettings.shared  // 本轮配置快照
        let promptContext: ReadingPromptContext = runKind == .none ? .reading : .evolution  // 讲解和进化两套历史
        if runKind != .none {  // 进化：去掉刚追加的用户句，避免历史里重复
            let userMessage = ChatMessage(role: .user, content: displayText)  // 屏上用 displayText，发给模型用 prompt
            host.appendDisplayedMessage(userMessage, to: promptContext)  // 写历史；当前 Tab 才上屏
        }
        if runKind == .none {  // 讲解：切到助手译文/讲解面板
            host.selectRightPageTab(.readingAssistant)  // 右页回到助手
            host.assistant.selectReadingAssistantPanel(.explanation)  // 讲解页
            host.assistant.readingAssistantActiveTask = .explanation  // 顶栏标「讲解中」
        }
        host.evolution.evolutionRunKind = runKind  // fetch 里按这个选 system prompt
        beginRun(showsExecutionTrace: runKind != .none)  // 讲解不露工具轨迹
        if runKind == .evolution {  // 记下命令号，失败好回滚
            host.evolution.executingEvolutionCommandNumber = evolutionCommandNumber  // 停止/出错时 revert
        } else {  // 讲解用模板历史
            host.evolution.executingEvolutionCommandNumber = nil  // 清掉上次残留
        }
        host.errorMessage = nil  // 新一轮清旧错

        let history: [ChatMessage]  // 真正发给模型的
        let readingLLMMode: AIBookLLMPrompt.Mode?  // 讲解才有固定 mode
        if runKind != .none {  // 进化：去掉刚追加的用户句，避免历史里重复
            history = Array(host.apiHistory(for: promptContext).dropLast())  // 当前 prompt 另传
            readingLLMMode = nil  // 进化不走读书 prompt 模板
        } else {  // 讲解用模板历史
            history = AIBookLLMPrompt.Mode.readingAssistant.apiHistory  // 欢迎语等已过滤
            readingLLMMode = .readingAssistant  // system prompt 用讲解那套
        }

        host.activeTask?.cancel()  // 取消上一轮，防两路写消息
        host.activeTask = Task {  // 主线程 Task，回调里再 hop
            do {
                let outcome = try await fetchAssistantReply(  // 进化走 Cursor，讲解走 LLM
                    prompt: prompt,
                    history: history,
                    settings: settings,
                    evolutionRunKind: runKind,
                    llmMode: readingLLMMode
                )

                guard !Task.isCancelled else { return }  // 取消不当失败
                let resolvedThinking = runKind != .none  // 讲解不存思考链
                    ? (outcome.thinking ?? (host.streamingThinking.isEmpty ? nil : host.streamingThinking))  // 结果优先，否则用流里拼的
                    : nil  // 讲解 thinking 丢掉
                let resolvedReply = outcome.text.isEmpty ? host.streamingResponse : outcome.text  // 结果空才用流

                if let notice = outcome.fallbackNotice {  // 回退通道提示单独一条
                    let noticeMessage = ChatMessage(role: .assistant, content: notice)  // 只上屏
                    host.appendDisplayedMessage(noticeMessage, to: promptContext)  // 在正式回复前
                }

                let assistantMessage = ChatMessage(  // 正文+思考+工具步骤
                    role: .assistant,
                    content: resolvedReply,
                    thinking: resolvedThinking,
                    toolSteps: runKind != .none ? resolvedToolStepsForMessage() : nil
                )
                host.appendDisplayedMessage(assistantMessage, to: promptContext)  // 写入对应历史

                if speakReplyWhenDone,  // 调用方要求读回复
                   !host.suppressReplySpeech,  // 用户点停止则不再读
                   !Task.isCancelled,  // 取消同理
                   !resolvedReply.isEmpty {  // 空回复不读
                    host.assistant.speakExplanation(resolvedReply, source: .aiReply)  // 记来源，工具栏能对上
                }

                if runKind == .analysis {  // 分析收成队列草稿
                    host.evolution.handleAnalysisCompletion(reply: resolvedReply)  // 解析建议并入队
                }

                if runKind == .evolution || runKind == .followUp {  // 记 token 估算
                    host.evolution.recordEvolutionCursorEstimate(  // 本轮消耗累加
                        prompt: prompt,
                        history: Array(history),
                        reply: resolvedReply,
                        thinking: resolvedThinking
                    )
                }

                if runKind == .evolution, triggerEvolutionRebuild {  // 改完文件才打包安装
                    let commandNumber = evolutionCommandNumber // 无入参则从用户文案抠命令号，再更新队列
                        ?? host.evolution.extractEvolutionCommandNumber(from: displayText)  // 「N、」
                    host.evolution.applyEvolutionQueueUpdate(reply: resolvedReply, commandNumber: commandNumber)  // pending → done

                    guard let projectURL = SelfEvolution.sourceProjectDirectory() else {  // 找不到源码目录就不装
                        host.errorMessage = BookL10n.string("vm.error.sourceProjectMissingShort")  // 短错，不打断对话
                        AutoEvolutionCoordinator.clearChain()  // 自动链停掉
                        return  // finally 仍会清 isRunning
                    }

                    let projectPath = projectURL.path  // 给打包脚本
                    let stillPending = host.evolution.optimizationQueue.nextPending() != nil  // 还有下一条才继续链
                    let continueChain = AppSettings.shared.autoEvolutionEnabled && stillPending  // 总开关也要开

                    host.appendDisplayedMessage(  // 告诉用户在升级
                        ChatMessage(  // 命令号可能抠不到，用 0
                            role: .assistant,
                            content: stillPending
                                ? BookL10n.format("vm.evolution.commandDoneUpgrade", commandNumber ?? 0)
                                : BookL10n.string("vm.evolution.allDoneUpgrade")
                        ),
                        to: .evolution
                    )
                    Task {  // 不阻塞当前收尾
                        await host.evolution.handleEvolutionRebuild( // 等待异步完成
                            projectPath: projectPath,
                            continueChain: continueChain
                        )
                    }
                }
            } catch {  // 失败：进化要回滚队列
                guard !Task.isCancelled else { return }  // 取消不当失败
                if runKind == .evolution, let number = evolutionCommandNumber {  // 有号才回滚
                    host.evolution.revertRunningOptimization(number: number)  // running 回 pending
                }
                if !(error is CancellationError) {  // 取消不弹错
                    let message = message(for: error, isEvolution: runKind != .none)  // 进化/讲解两套文案
                    host.errorMessage = message  // 顶栏
                    let failureMessage = ChatMessage(role: .assistant, content: BookL10n.format("vm.error.parseFailed", message))  // 对话里也留一条
                    host.appendDisplayedMessage(failureMessage, to: promptContext)  // 写进对应历史
                }
            }
            host.isLoading = false  // 无论成败收转圈
            host.isRunning = false  // 停止按钮灰掉
            host.activeTask = nil  // 允许下一轮
            resetStreamingState()  // 清流，避免残字
            host.evolution.clearEvolutionExecutionState()  // 清命令号和轨迹开关
        }
    }


    /// 把错误转成界面可展示的简体中文说明（进化与读书助手分支不同）。
    private func message(for error: Error, isEvolution: Bool) -> String {
        if isEvolution {  // 进化错误单独处理 Cursor 鉴权
            if let llmError = error as? LLMServiceError,  // 偶尔进化也会碰到 LLM 错
               let description = llmError.errorDescription {  // 有本地化就用
                return description  // 非鉴权就原文
            }
            if case CursorServiceError.needsAuthentication = error {  // 没 Key 的专门说明
                // 原描述 + 提示
                return """
                Cursor 需要有效的 API Key（AuthenticationError）。
                请在「进化设置」填写 Cursor API Key，或创建 ai-book/cursor.local.env。
                进化功能仅使用 Cursor 本地 Agent，不使用读书助手的大模型 API。
                """
            }
            if let localized = error as? LocalizedError,  // 其他 LocalizedError
               let description = localized.errorDescription,  // 空描述不用
               !description.isEmpty {  // 防空串
                let lower = description.lowercased()  // 英文接口常写 api key
                if lower.contains("api key") || lower.contains("authentication") {  // 补一句别用 DeepSeek Key
                    // 原描述 + 提示
                    return """
                    \(description)

                    提示：进化功能使用 Cursor 本地 Agent。请在「进化设置」配置 Cursor API Key，勿使用 book 设置中的 DeepSeek 等 API Key。
                    """
                }
                return description  // 非鉴权就原文
            }
            return error.localizedDescription  // 兜底
        }
        return LLMServiceErrorPresenter.message(  // 讲解走读书 provider 文案
            for: error,
            provider: AppSettings.shared.bookProvider
        )
    }


    /// 讲解走 LLM，进化/分析走 Cursor。
    func fetchAssistantReply(
        prompt: String,
        history: [ChatMessage],
        settings: AppSettings,
        evolutionRunKind: ReadingEvolutionRunKind = .none,
        llmMode: AIBookLLMPrompt.Mode? = nil
    ) async throws -> ReadingViewModel.AssistantReplyOutcome {
        let resolvedSystemPrompt: String  // 按 runKind 选系统提示
        switch host.evolution.evolutionRunKind {  // 四种会话策略
        case .analysis:  // 一次一 Agent，跑完关
            resolvedSystemPrompt = EvolutionAnalyzer.analysisSystemPrompt  // 分析专用
        case .evolution, .followUp:  // 改文件 / 追问同一套
            resolvedSystemPrompt = EvolutionAssistant.systemPrompt  // 进化助手
        case .none:  // 理论上走不到，防守默认
            resolvedSystemPrompt = llmMode?.systemPrompt ?? ReadingAssistant.systemPrompt  // 有 mode 用模板，否则默认
        }
        let isEvolutionTask = host.evolution.evolutionRunKind != .none  // 分析也走 Cursor
        let readingConfiguration = settings.bookLLMConfiguration  // 讲解通道

        if isEvolutionTask {  // 先拦源码/Key 配置
            if let configError = AppGuard.evolutionSourceErrorMessage(for: settings) {  // fail-closed
                throw EvolutionServiceError.notConfigured(configError) // 向上抛出错误
            }
            return try await fetchCursorReply(  // 本地 Agent
                prompt: prompt,
                history: history,
                settings: settings,
                systemInstruction: resolvedSystemPrompt,
                evolutionRunKind: host.evolution.evolutionRunKind
            )
        }

        guard settings.isBookLLMConfigured else {  // 讲解没配 Key 直接失败
            throw LLMServiceError.missingAPIKey(provider: settings.bookProvider) // 向上抛出错误
        }

        let llmText = try await fetchLLMReply(  // 流式拼进 host.streamingResponse
            prompt: prompt,
            history: history,
            configuration: readingConfiguration,
            systemPrompt: resolvedSystemPrompt
        )
        return ReadingViewModel.AssistantReplyOutcome(text: llmText, thinking: nil, fallbackNotice: nil)  // 讲解没有思考链
    }


    /// Cursor 本地 Agent；分析关会话，进化留下给追问。
    func fetchCursorReply(
        prompt: String,
        history: [ChatMessage],
        settings: AppSettings,
        systemInstruction: String,
        evolutionRunKind: ReadingEvolutionRunKind
    ) async throws -> ReadingViewModel.AssistantReplyOutcome {
        guard let cursorConfig = settings.cursorConfiguration else {  // 没配桥就不打
            throw CursorServiceError.bridgeNotFound // 向上抛出错误
        }

        let sessionMode: CursorSessionMode = host.evolution.evolutionRunKind == .analysis ? .analysis : .evolution  // 分析会话隔离
        let freshAgent: Bool  // 是否新开 Agent
        let agentId: String?  // 追问才复用
        let closeAgentAfterRun: Bool  // 分析跑完关掉，进化留下给追问
        let autoAuthorize: Bool  // 进化自动批工具

        switch host.evolution.evolutionRunKind {  // 四种会话策略
        case .analysis:  // 一次一 Agent，跑完关
            freshAgent = true  // 新开
            agentId = nil  // 无会话
            closeAgentAfterRun = true  // 分析不留会话
            autoAuthorize = false  // 不自动批
        case .evolution:  // 新开并清旧会话
            EvolutionCursorSession.clear()  // 避免下次误复用
            freshAgent = true  // 新开
            agentId = nil  // 无会话
            closeAgentAfterRun = false  // 不主动关
            autoAuthorize = true  // 追问也可能改文件
        case .followUp:  // 接着当前 Agent
            freshAgent = false  // 复用
            agentId = EvolutionCursorSession.agentId  // 没有则桥自己处理
            closeAgentAfterRun = false  // 不主动关
            autoAuthorize = true  // 追问也可能改文件
        case .none:  // 理论上走不到，防守默认
            freshAgent = true  // 新开
            agentId = nil  // 无会话
            closeAgentAfterRun = false  // 不主动关
            autoAuthorize = false  // 不自动批
        }

        let result = try await host.cursorService.chat(  // 事件回调回主线程
            message: prompt,
            history: history,
            configuration: cursorConfig,
            systemInstruction: systemInstruction,
            autoAuthorize: autoAuthorize,
            sessionMode: sessionMode,
            freshAgent: freshAgent,
            agentId: agentId,
            closeAgentAfterRun: closeAgentAfterRun,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleCursorStreamEvent(event)
                }
            }
        )

        if let usage = result.usage {  // 有用量才记
            host.evolution.recordEvolutionTokenUsage(usage)  // 累加本会话
        }
        if let agentId = result.agentId, !agentId.isEmpty, !closeAgentAfterRun {  // 留下给追问
            EvolutionCursorSession.save(agentId: agentId, requestId: result.requestId)  // 下次 followUp 用
        }
        if closeAgentAfterRun {  // 分析跑完清
            EvolutionCursorSession.clear()  // 避免下次误复用
        }
        if let requestId = result.requestId {  // 排错用
            host.evolution.evolutionLastRequestId = requestId  // 设置页/日志能对上
        }

        return ReadingViewModel.AssistantReplyOutcome(text: result.text, thinking: result.thinking, fallbackNotice: nil)  // Cursor 不走 LLM 回退
    }


    /// 读书助手 LLM。缺 Key fail-closed。
    func fetchLLMReply(
        prompt: String,
        history: [ChatMessage],
        configuration: LLMConfiguration,
        systemPrompt: String
    ) async throws -> String {
        if configuration.provider.requiresAPIKey && configuration.apiKey.isEmpty {  // 本地 Ollama 不要 Key
            throw LLMServiceError.missingAPIKey(provider: configuration.provider) // 向上抛出错误
        }

        return try await host.llmService.chat(  // 流事件回主线程拼 delta
            prompt: prompt,
            history: history,
            configuration: configuration,
            systemPrompt: systemPrompt,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleLLMStreamEvent(event)
                }
            }
        )
    }
}

import AIBookEvolution
import Foundation

@MainActor
/// 读书/进化消息的流式请求编排（LLM 与 Cursor）。
final class ReadingMessageOrchestrator {
    unowned var host: ReadingViewModel!

    func resetStreamingState() {
        host.streamingThinking = ""
        host.streamingResponse = ""
        host.streamingToolStatus = ""
        host.streamingToolSteps = []
        host.evolution.evolutionAgentContextTokens = 0
        host.evolution.showsExecutionTrace = false
        host.assistant.readingAssistantActiveTask = nil
    }


    func beginRun(showsExecutionTrace: Bool) {
        host.isLoading = true
        host.isRunning = true
        host.suppressReplySpeech = false
        resetStreamingState()
        host.evolution.showsExecutionTrace = showsExecutionTrace
    }


    func handleLLMStreamEvent(_ event: LLMStreamEvent) {
        switch event {
        case .textDelta(let delta):
            host.streamingResponse += delta
        case .done, .error:
            break
        }
    }


    func handleCursorStreamEvent(_ event: CursorStreamEvent) {
        switch event {
        case .thinkingDelta(let delta):
            guard host.evolution.showsExecutionTrace else { return }
            host.streamingThinking += delta
        case .textDelta(let delta):
            host.streamingResponse += delta
        case .toolUpdate(let name, let status, let callId, let detail, let result, let error):
            guard host.evolution.showsExecutionTrace else { return }
            applyToolStepUpdate(
                name: name,
                status: status,
                callId: callId,
                detail: detail,
                result: result,
                error: error
            )
        case .statusUpdate(let status):
            guard host.evolution.showsExecutionTrace else { return }
            host.streamingToolStatus = status
        case .error(let message):
            host.errorMessage = message
        case .done(let text, let thinking):
            if host.streamingResponse.isEmpty, !text.isEmpty {
                host.streamingResponse = text
            }
            guard host.evolution.showsExecutionTrace else { return }
            if host.streamingThinking.isEmpty, let thinking, !thinking.isEmpty {
                host.streamingThinking = thinking
            }
        }
    }


    func applyToolStepUpdate(
        name: String,
        status: String,
        callId: String?,
        detail: String?,
        result: String?,
        error: String?
    ) {
        let stepStatus: ExecutionStep.Status
        switch status {
        case "completed":
            stepStatus = .completed
        case "failed", "error":
            stepStatus = .failed
        default:
            stepStatus = .running
        }

        let completionTime = stepStatus == .running ? nil : Date()

        if stepStatus == .running {
            if let callId,
               let index = host.streamingToolSteps.lastIndex(where: { $0.callId == callId }) {
                let existing = host.streamingToolSteps[index]
                if existing.status == .running {
                    if let detail, !detail.isEmpty {
                        host.streamingToolSteps[index] = ExecutionStep(
                            id: existing.id,
                            callId: existing.callId,
                            name: name,
                            detail: detail,
                            status: .running,
                            startedAt: existing.startedAt
                        )
                    }
                    return
                }
            }
            host.streamingToolSteps.append(
                ExecutionStep(callId: callId, name: name, detail: detail, status: .running)
            )
        } else if let callId,
                  let index = host.streamingToolSteps.lastIndex(where: { $0.callId == callId }) {
            let existing = host.streamingToolSteps[index]
            host.streamingToolSteps[index] = ExecutionStep(
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
        } else if let index = host.streamingToolSteps.lastIndex(where: { $0.name == name && $0.status == .running }) {
            let existing = host.streamingToolSteps[index]
            host.streamingToolSteps[index] = ExecutionStep(
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
        } else {
            host.streamingToolSteps.append(
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

        host.streamingToolStatus = stepStatus == .running
            ? BookL10n.format("vm.tool.running", EvolutionToolLabels.localizedToolName(name))
            : BookL10n.format("vm.tool.done", EvolutionToolLabels.localizedToolName(name))
    }


    func resolvedToolStepsForMessage() -> [ExecutionStep]? {
        host.streamingToolSteps.isEmpty ? nil : host.streamingToolSteps
    }


    func sendMessage(
        _ prompt: String,
        displayText: String,
        isEvolution: Bool = false,
        evolutionCommandNumber: Int? = nil,
        speakReplyWhenDone: Bool = false,
        triggerEvolutionRebuild: Bool = false,
        evolutionRunKind: ReadingEvolutionRunKind = .none
    ) {
        let runKind = evolutionRunKind == .none
            ? (isEvolution ? ReadingEvolutionRunKind.evolution : .none)
            : evolutionRunKind
        let settings = AppSettings.shared
        let promptContext: ReadingPromptContext = runKind == .none ? .reading : .evolution
        if runKind != .none {
            let userMessage = ChatMessage(role: .user, content: displayText)
            host.appendDisplayedMessage(userMessage, to: promptContext)
        }
        if runKind == .none {
            host.selectRightPageTab(.readingAssistant)
            host.assistant.selectReadingAssistantPanel(.explanation)
            host.assistant.readingAssistantActiveTask = .explanation
        }
        host.evolution.evolutionRunKind = runKind
        beginRun(showsExecutionTrace: runKind != .none)
        if runKind == .evolution {
            host.evolution.executingEvolutionCommandNumber = evolutionCommandNumber
        } else {
            host.evolution.executingEvolutionCommandNumber = nil
        }
        host.errorMessage = nil

        let history: [ChatMessage]
        let readingLLMMode: AIBookLLMPrompt.Mode?
        if runKind != .none {
            history = Array(host.apiHistory(for: promptContext).dropLast())
            readingLLMMode = nil
        } else {
            history = AIBookLLMPrompt.Mode.readingAssistant.apiHistory
            readingLLMMode = .readingAssistant
        }

        host.activeTask?.cancel()
        host.activeTask = Task {
            do {
                let outcome = try await fetchAssistantReply(
                    prompt: prompt,
                    history: history,
                    settings: settings,
                    evolutionRunKind: runKind,
                    llmMode: readingLLMMode
                )

                guard !Task.isCancelled else { return }
                let resolvedThinking = runKind != .none
                    ? (outcome.thinking ?? (host.streamingThinking.isEmpty ? nil : host.streamingThinking))
                    : nil
                let resolvedReply = outcome.text.isEmpty ? host.streamingResponse : outcome.text

                if let notice = outcome.fallbackNotice {
                    let noticeMessage = ChatMessage(role: .assistant, content: notice)
                    host.appendDisplayedMessage(noticeMessage, to: promptContext)
                }

                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: resolvedReply,
                    thinking: resolvedThinking,
                    toolSteps: runKind != .none ? resolvedToolStepsForMessage() : nil
                )
                host.appendDisplayedMessage(assistantMessage, to: promptContext)

                if speakReplyWhenDone,
                   !host.suppressReplySpeech,
                   !Task.isCancelled,
                   !resolvedReply.isEmpty {
                    host.assistant.speakExplanation(resolvedReply, source: .aiReply)
                }

                if runKind == .analysis {
                    host.evolution.handleAnalysisCompletion(reply: resolvedReply)
                }

                if runKind == .evolution || runKind == .followUp {
                    host.evolution.recordEvolutionCursorEstimate(
                        prompt: prompt,
                        history: Array(history),
                        reply: resolvedReply,
                        thinking: resolvedThinking
                    )
                }

                if runKind == .evolution, triggerEvolutionRebuild {
                    let commandNumber = evolutionCommandNumber
                        ?? host.evolution.extractEvolutionCommandNumber(from: displayText)
                    host.evolution.applyEvolutionQueueUpdate(reply: resolvedReply, commandNumber: commandNumber)

                    guard let projectURL = SelfEvolution.sourceProjectDirectory() else {
                        host.errorMessage = BookL10n.string("vm.error.sourceProjectMissingShort")
                        AutoEvolutionCoordinator.clearChain()
                        return
                    }

                    let projectPath = projectURL.path
                    let stillPending = host.evolution.optimizationQueue.nextPending() != nil
                    let continueChain = AppSettings.shared.autoEvolutionEnabled && stillPending

                    host.appendDisplayedMessage(
                        ChatMessage(
                            role: .assistant,
                            content: stillPending
                                ? BookL10n.format("vm.host.evolution.commandDoneUpgrade", commandNumber ?? 0)
                                : BookL10n.string("vm.host.evolution.allDoneUpgrade")
                        ),
                        to: .evolution
                    )
                    Task {
                        await host.evolution.handleEvolutionRebuild(
                            projectPath: projectPath,
                            continueChain: continueChain
                        )
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                if runKind == .evolution, let number = evolutionCommandNumber {
                    host.evolution.revertRunningOptimization(number: number)
                }
                if !(error is CancellationError) {
                    let message = message(for: error, isEvolution: runKind != .none)
                    host.errorMessage = message
                    let failureMessage = ChatMessage(role: .assistant, content: BookL10n.format("vm.error.parseFailed", message))
                    host.appendDisplayedMessage(failureMessage, to: promptContext)
                }
            }
            host.isLoading = false
            host.isRunning = false
            host.activeTask = nil
            resetStreamingState()
            host.evolution.clearEvolutionExecutionState()
        }
    }


    private func message(for error: Error, isEvolution: Bool) -> String {
        if isEvolution {
            if let llmError = error as? LLMServiceError,
               let description = llmError.errorDescription {
                return description
            }
            if case CursorServiceError.needsAuthentication = error {
                return """
                Cursor 需要有效的 API Key（AuthenticationError）。
                请在「进化设置」填写 Cursor API Key，或创建 ai-book/cursor.local.env。
                进化功能仅使用 Cursor 本地 Agent，不使用读书助手的大模型 API。
                """
            }
            if let localized = error as? LocalizedError,
               let description = localized.errorDescription,
               !description.isEmpty {
                let lower = description.lowercased()
                if lower.contains("api key") || lower.contains("authentication") {
                    return """
                    \(description)

                    提示：进化功能使用 Cursor 本地 Agent。请在「进化设置」配置 Cursor API Key，勿使用 book 设置中的 DeepSeek 等 API Key。
                    """
                }
                return description
            }
            return error.localizedDescription
        }
        return LLMServiceErrorPresenter.message(
            for: error,
            provider: AppSettings.shared.bookProvider
        )
    }


    func fetchAssistantReply(
        prompt: String,
        history: [ChatMessage],
        settings: AppSettings,
        evolutionRunKind: ReadingEvolutionRunKind = .none,
        llmMode: AIBookLLMPrompt.Mode? = nil
    ) async throws -> ReadingViewModel.AssistantReplyOutcome {
        let resolvedSystemPrompt: String
        switch host.evolution.evolutionRunKind {
        case .analysis:
            resolvedSystemPrompt = EvolutionAnalyzer.analysisSystemPrompt
        case .evolution, .followUp:
            resolvedSystemPrompt = EvolutionAssistant.systemPrompt
        case .none:
            resolvedSystemPrompt = llmMode?.systemPrompt ?? ReadingAssistant.systemPrompt
        }
        let isEvolutionTask = host.evolution.evolutionRunKind != .none
        let readingConfiguration = settings.bookLLMConfiguration

        if isEvolutionTask {
            if let configError = AppGuard.evolutionSourceErrorMessage(for: settings) {
                throw EvolutionServiceError.notConfigured(configError)
            }
            return try await fetchCursorReply(
                prompt: prompt,
                history: history,
                settings: settings,
                systemInstruction: resolvedSystemPrompt,
                evolutionRunKind: host.evolution.evolutionRunKind
            )
        }

        guard settings.isBookLLMConfigured else {
            throw LLMServiceError.missingAPIKey(provider: settings.bookProvider)
        }

        let llmText = try await fetchLLMReply(
            prompt: prompt,
            history: history,
            configuration: readingConfiguration,
            systemPrompt: resolvedSystemPrompt
        )
        return ReadingViewModel.AssistantReplyOutcome(text: llmText, thinking: nil, fallbackNotice: nil)
    }


    func fetchCursorReply(
        prompt: String,
        history: [ChatMessage],
        settings: AppSettings,
        systemInstruction: String,
        evolutionRunKind: ReadingEvolutionRunKind
    ) async throws -> ReadingViewModel.AssistantReplyOutcome {
        guard let cursorConfig = settings.cursorConfiguration else {
            throw CursorServiceError.bridgeNotFound
        }

        let sessionMode: CursorSessionMode = host.evolution.evolutionRunKind == .analysis ? .analysis : .evolution
        let freshAgent: Bool
        let agentId: String?
        let closeAgentAfterRun: Bool
        let autoAuthorize: Bool

        switch host.evolution.evolutionRunKind {
        case .analysis:
            freshAgent = true
            agentId = nil
            closeAgentAfterRun = true
            autoAuthorize = false
        case .evolution:
            EvolutionCursorSession.clear()
            freshAgent = true
            agentId = nil
            closeAgentAfterRun = false
            autoAuthorize = true
        case .followUp:
            freshAgent = false
            agentId = EvolutionCursorSession.agentId
            closeAgentAfterRun = false
            autoAuthorize = true
        case .none:
            freshAgent = true
            agentId = nil
            closeAgentAfterRun = false
            autoAuthorize = false
        }

        let result = try await host.cursorService.chat(
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

        if let usage = result.usage {
            host.evolution.recordEvolutionTokenUsage(usage)
        }
        if let agentId = result.agentId, !agentId.isEmpty, !closeAgentAfterRun {
            EvolutionCursorSession.save(agentId: agentId, requestId: result.requestId)
        }
        if closeAgentAfterRun {
            EvolutionCursorSession.clear()
        }
        if let requestId = result.requestId {
            host.evolution.evolutionLastRequestId = requestId
        }

        return ReadingViewModel.AssistantReplyOutcome(text: result.text, thinking: result.thinking, fallbackNotice: nil)
    }


    func fetchLLMReply(
        prompt: String,
        history: [ChatMessage],
        configuration: LLMConfiguration,
        systemPrompt: String
    ) async throws -> String {
        if configuration.provider.requiresAPIKey && configuration.apiKey.isEmpty {
            throw LLMServiceError.missingAPIKey(provider: configuration.provider)
        }

        return try await host.llmService.chat(
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

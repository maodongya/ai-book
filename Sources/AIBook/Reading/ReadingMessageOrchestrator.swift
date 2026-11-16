import Foundation

@MainActor
/// 读书消息的流式请求编排。只走书内大模型。
final class ReadingMessageOrchestrator {
    unowned var host: ReadingViewModel!

    func resetStreamingState() {
        host.streamingThinking = ""
        host.streamingResponse = ""
        host.streamingToolStatus = ""
        host.streamingToolSteps = []
        host.assistant.readingAssistantActiveTask = nil
    }

    func beginRun(showsExecutionTrace: Bool) {
        host.isLoading = true
        host.isRunning = true
        host.suppressReplySpeech = false
        resetStreamingState()
        _ = showsExecutionTrace
    }

    func handleLLMStreamEvent(_ event: LLMStreamEvent) {
        switch event {
        case .textDelta(let delta):
            if host.assistant.readingAssistantActiveTask == .translation {
                host.translation.appendTranslationStreamPreview(delta)
            } else if host.assistant.readingAssistantActiveTask == .explanation,
                      host.assistant.showsExplanationProgressSheet {
                host.assistant.appendExplanationStreamPreview(delta)
            } else {
                host.streamingResponse += delta
            }
        case .done, .error:
            break
        }
    }

    func fetchAssistantReply(
        prompt: String,
        history: [ChatMessage],
        settings: AppSettings,
        llmMode: AIBookLLMPrompt.Mode? = nil
    ) async throws -> ReadingViewModel.AssistantReplyOutcome {
        let resolvedSystemPrompt = llmMode?.systemPrompt ?? ReadingAssistant.systemPrompt
        let readingConfiguration = settings.bookLLMConfiguration

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

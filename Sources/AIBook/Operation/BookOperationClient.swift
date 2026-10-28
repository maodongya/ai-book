import Foundation

/// 用当前读书后端做一轮操作解析。Cursor 只回 JSON，不改文件。
final class BookOperationClient: OperationCompletionClient {
    private let llmService: LLMService
    private let cursorService: CursorService

    init(llmService: LLMService, cursorService: CursorService) {
        self.llmService = llmService
        self.cursorService = cursorService
    }

    /// 跟顶栏的讲解来源走。工具结果不发回模型。
    func complete(userMessage: String, tools: [[String: Any]]) async throws -> LLMCompletionResult {
        let settings = await MainActor.run { AppSettings.shared } // 设置在主线程
        let source = await MainActor.run { settings.explanationSource }
        switch source {
        case .llm:
            let messages: [[String: Any]] = [
                ["role": "system", "content": OperationPromptBuilder.systemPrompt],
                ["role": "user", "content": userMessage],
            ]
            return try await llmService.completeWithTools(
                messages: messages,
                tools: tools,
                configuration: await MainActor.run { settings.bookLLMConfiguration }
            )
        case .cursor:
            guard let configuration = await MainActor.run(body: { settings.cursorConfiguration }) else {
                throw CursorServiceError.needsAuthentication // 没桥或没 Key
            }
            let result = try await cursorService.chat(
                message: userMessage,
                history: [],
                configuration: configuration,
                systemInstruction: OperationPromptBuilder.systemPrompt,
                autoAuthorize: false, // 不许改仓库
                sessionMode: .analysis,
                freshAgent: true,
                closeAgentAfterRun: true
            )
            return LLMCompletionResult(
                content: result.text,
                reasoning: result.thinking,
                toolCalls: [],
                usage: result.usage ?? .zero
            )
        }
    }
}

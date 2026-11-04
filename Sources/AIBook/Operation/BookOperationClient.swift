import Foundation

/// 用翻译和讲解同一套读书大模型做一轮操作解析。不走 Cursor。
final class BookOperationClient: OperationCompletionClient {
    private let llmService: LLMService

    init(llmService: LLMService) {
        self.llmService = llmService
    }

    /// 工具结果不发回模型。模型档案与讲解、翻译相同。
    func complete(userMessage: String, tools: [[String: Any]]) async throws -> LLMCompletionResult {
        let configuration = await MainActor.run { AppSettings.shared.bookLLMConfiguration } // 设置在主线程
        let messages: [[String: Any]] = [
            ["role": "system", "content": OperationPromptBuilder.systemPrompt],
            ["role": "user", "content": userMessage],
        ]
        return try await llmService.completeWithTools(
            messages: messages,
            tools: tools,
            configuration: configuration
        )
    }
}

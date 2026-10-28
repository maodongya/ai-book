import Foundation

/// 一轮操作解析的模型入口。实现方自己带系统提示，这里只发用户消息和工具表。
protocol OperationCompletionClient {
    func complete(userMessage: String, tools: [[String: Any]]) async throws -> LLMCompletionResult
}

/// 松开麦克风后的一轮请求。不把工具结果发回模型。
enum OperationPlanner {
    static func plan(
        utterance: String,
        snapshot: OperationContextSnapshot,
        client: OperationCompletionClient
    ) async throws -> OperationPlan {
        let message = OperationPromptBuilder.userMessage(utterance: utterance, snapshot: snapshot) // 原话加短快照
        let tools = OperationCatalog.toolDefinitions() // 封闭目录
        let result = try await client.complete(userMessage: message, tools: tools) // 只请求一次
        return OperationPlanParser.parse(toolCalls: result.toolCalls, content: result.content ?? "") // 有工具调用就不用正文
    }
}

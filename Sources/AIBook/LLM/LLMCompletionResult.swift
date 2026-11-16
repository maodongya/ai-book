import Foundation

/// 模型返回的一次 function 调用。arguments 是 JSON 字符串。
struct LLMToolCall: Equatable {
    let id: String
    let name: String
    let arguments: String
}

/// 一轮补全：正文、思考、工具调用、用量。
struct LLMCompletionResult {
    let content: String?
    let reasoning: String?
    let toolCalls: [LLMToolCall]
    let usage: LLMTokenUsage
}

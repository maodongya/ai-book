import Foundation

/// 一条对话。assistant 可带思考和工具时间线。旧进化消息仍能读出来。
struct ChatMessage: Identifiable, Equatable, Codable {
    /// 只有 user/assistant。系统提示不进这条。
    enum Role: String, Codable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var content: String
    let thinking: String?
    let toolSteps: [ExecutionStep]?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        thinking: String? = nil,
        toolSteps: [ExecutionStep]? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.thinking = thinking
        self.toolSteps = toolSteps
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case id, role, content, thinking, toolSteps, timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(Role.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        thinking = try container.decodeIfPresent(String.self, forKey: .thinking)
        toolSteps = try container.decodeIfPresent([ExecutionStep].self, forKey: .toolSteps)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }

    var hasExecutionTrace: Bool {
        let thinkingText = thinking?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !thinkingText.isEmpty || !(toolSteps?.isEmpty ?? true)
    }
}

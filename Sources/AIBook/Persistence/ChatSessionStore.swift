import Foundation

/// 落盘的阅读/进化会话。旧字段 messages/chatInput 仍解码，新代码读写分栏字段。
struct PersistedChatSession: Codable {
    var messages: [ChatMessage] // 历史：曾是单一聊天；现作 reading 回退
    var chatInput: String
    var lastOpenedFilePath: String?
    var lessonPlanContent: String? // 译文/讲解稿，名字是历史遗留
    var translationAlignment: TranslationAlignment?
    var scrollSyncEnabled: Bool?
    var translationTableViewEnabled: Bool?
    var readingComparisonEnabled: Bool?
    var readingMessages: [ChatMessage]?
    var evolutionMessages: [ChatMessage]?
    var readingChatInput: String?
    var evolutionChatInput: String?
    var rightPageTab: String?
    var readingAssistantPanel: String?
}

/// Application Support 里的 chat-session.json。
final class ChatSessionStore {
    static let shared = ChatSessionStore()

    private let fileName = "chat-session.json"

    private var sessionURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("AIBook", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    /// 没有文件返回 nil，让调用方走默认空会话。
    func load() throws -> PersistedChatSession? {
        guard FileManager.default.fileExists(atPath: sessionURL.path) else { return nil }
        let data = try Data(contentsOf: sessionURL)
        return try JSONDecoder().decode(PersistedChatSession.self, from: data)
    }

    /// 同时写下阅读/进化两套消息。旧 messages 仍填 reading，兼容只认旧字段的解码。
    func save(
        readingMessages: [ChatMessage],
        evolutionMessages: [ChatMessage],
        readingChatInput: String,
        evolutionChatInput: String,
        rightPageTab: RightPageTab,
        readingAssistantPanel: ReadingAssistantPanel,
        lastOpenedFilePath: String?,
        lessonPlanContent: String,
        translationAlignment: TranslationAlignment?,
        translationTableViewEnabled: Bool
    ) throws {
        let session = PersistedChatSession(
            messages: readingMessages, // 旧字段 = 阅读，避免升级后丢掉气泡
            chatInput: readingChatInput,
            lastOpenedFilePath: lastOpenedFilePath,
            lessonPlanContent: lessonPlanContent,
            translationAlignment: translationAlignment,
            translationTableViewEnabled: translationTableViewEnabled,
            readingMessages: readingMessages,
            evolutionMessages: evolutionMessages,
            readingChatInput: readingChatInput,
            evolutionChatInput: evolutionChatInput,
            rightPageTab: rightPageTab.rawValue,
            readingAssistantPanel: readingAssistantPanel.rawValue
        )
        let data = try JSONEncoder().encode(session)
        try data.write(to: sessionURL, options: .atomic)
    }
}

import Foundation

struct PersistedChatSession: Codable {
    var messages: [ChatMessage]
    var chatInput: String
    var lastOpenedFilePath: String?
    var lessonPlanContent: String?
    var translationAlignment: TranslationAlignment?
    var scrollSyncEnabled: Bool?
    var readingMessages: [ChatMessage]?
    var evolutionMessages: [ChatMessage]?
    var readingChatInput: String?
    var evolutionChatInput: String?
    var rightPageTab: String?
    var readingAssistantPanel: String?
}

final class ChatSessionStore {
    static let shared = ChatSessionStore()

    private let fileName = "chat-session.json"

    private var sessionURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("AIBook", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    func load() throws -> PersistedChatSession? {
        guard FileManager.default.fileExists(atPath: sessionURL.path) else { return nil }
        let data = try Data(contentsOf: sessionURL)
        return try JSONDecoder().decode(PersistedChatSession.self, from: data)
    }

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
        scrollSyncEnabled: Bool
    ) throws {
        let session = PersistedChatSession(
            messages: readingMessages,
            chatInput: readingChatInput,
            lastOpenedFilePath: lastOpenedFilePath,
            lessonPlanContent: lessonPlanContent,
            translationAlignment: translationAlignment,
            scrollSyncEnabled: scrollSyncEnabled,
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

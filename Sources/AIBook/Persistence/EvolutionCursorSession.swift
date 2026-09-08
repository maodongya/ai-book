import Foundation

/// Persists Cursor SDK local `agentId` for AI 进化多轮追问（`Agent.resume`）。
enum EvolutionCursorSession {
    private static let fileName = "cursor-evolution-agent.json"

    struct State: Codable, Equatable {
        var agentId: String
        var updatedAt: Date
        var lastRequestId: String?
    }

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("AIBook", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    static func load() -> State? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(State.self, from: data)
    }

    static func save(agentId: String, requestId: String? = nil) {
        let state = State(agentId: agentId, updatedAt: Date(), lastRequestId: requestId)
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static var agentId: String? {
        load()?.agentId
    }

    static var lastRequestId: String? {
        load()?.lastRequestId
    }
}

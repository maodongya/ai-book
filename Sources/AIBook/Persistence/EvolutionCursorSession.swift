import Foundation

/// 持久化 Cursor SDK 本地 `agentId`，给 AI 进化多轮追问（`Agent.resume`）。不存对话正文。
enum EvolutionCursorSession {
    private static let fileName = "cursor-evolution-agent.json"

    /// 磁盘上的一小段状态：agent、更新时间和可选的上次 request。
    struct State: Codable, Equatable {
        var agentId: String // Cursor 侧会话 id，resume 必须带上
        var updatedAt: Date
        var lastRequestId: String? // 可选，排障用
    }

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("AIBook", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    /// 没有文件或坏 JSON 都当没有会话。
    static func load() -> State? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(State.self, from: data)
    }

    /// 覆盖写入新的 agent。编码失败静默，下次再试。
    static func save(agentId: String, requestId: String? = nil) {
        let state = State(agentId: agentId, updatedAt: Date(), lastRequestId: requestId)
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 用户新开进化或失败清链时删掉，避免 resume 到旧 agent。
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

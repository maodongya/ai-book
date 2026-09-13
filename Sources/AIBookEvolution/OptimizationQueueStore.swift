import Foundation

/// 优化队列 JSON 的读写与从命令笔记的一次性迁移。
public final class OptimizationQueueStore {
    /// 队列文件位置，测试可注入。
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// 默认：Application Support/AIBook/optimization-queue.json
    public static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("AIBook", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("optimization-queue.json")
    }

    /// 文件不存在当空队列，不抛错。
    public func load() throws -> OptimizationQueue {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .empty
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // 与 save 对称
        return try decoder.decode(OptimizationQueue.self, from: data)
    }

    /// 美化 JSON + 排序 key，方便 diff 和人工看。
    public func save(_ queue: OptimizationQueue) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(queue)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    /// 还没有 JSON 时从左页笔记导入一次；已有文件则只 load，不再覆盖。
    public func migrateFromReadmeNotesIfNeeded(_ notes: String) throws -> OptimizationQueue {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return try load() // 已经迁过
        }
        let queue = OptimizationQueue.importFromNotes(notes)
        guard !queue.items.isEmpty else {
            let empty = OptimizationQueue.empty
            try save(empty) // 写下空文件，避免下次再解析笔记
            return empty
        }
        try save(queue)
        return queue
    }
}

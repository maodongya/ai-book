import Foundation

public final class OptimizationQueueStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("AIBook", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("optimization-queue.json")
    }

    public func load() throws -> OptimizationQueue {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .empty
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OptimizationQueue.self, from: data)
    }

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

    public func migrateFromReadmeNotesIfNeeded(_ notes: String) throws -> OptimizationQueue {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return try load()
        }
        let queue = OptimizationQueue.importFromNotes(notes)
        guard !queue.items.isEmpty else {
            let empty = OptimizationQueue.empty
            try save(empty)
            return empty
        }
        try save(queue)
        return queue
    }
}

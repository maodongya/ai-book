import Foundation

/// Tracks automatic self-evolution / upgrade chain across relaunches.
enum AutoEvolutionCoordinator {
    private static let flagFileName = "auto-evolution-active"

    private static var flagURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("AIBook", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(flagFileName)
    }

    static var isChainActive: Bool {
        FileManager.default.fileExists(atPath: flagURL.path)
    }

    static func markChainActive() {
        FileManager.default.createFile(atPath: flagURL.path, contents: Data("1".utf8))
    }

    static func clearChain() {
        try? FileManager.default.removeItem(at: flagURL)
    }

    static func shouldAutoStart(autoEvolutionEnabled: Bool, pendingCount: Int) -> Bool {
        autoEvolutionEnabled && pendingCount > 0
    }
}

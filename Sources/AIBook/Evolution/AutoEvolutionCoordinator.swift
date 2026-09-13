import Foundation

/// 用 Application Support 里的旗标文件记住「进化链还在跑」，跨 relaunch 仍在。
enum AutoEvolutionCoordinator {
    /// 旗标文件名，只表示链是否活跃，不存队列内容。
    private static let flagFileName = "auto-evolution-active"

    /// ~/Library/Application Support/AIBook/auto-evolution-active
    private static var flagURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("AIBook", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) // 目录不存在就建
        return directory.appendingPathComponent(flagFileName)
    }

    /// 旗标文件在就是链还活着。
    static var isChainActive: Bool {
        FileManager.default.fileExists(atPath: flagURL.path)
    }

    /// 构建成功、还要继续下一轮时写下旗标。
    static func markChainActive() {
        FileManager.default.createFile(atPath: flagURL.path, contents: Data("1".utf8)) // 内容无意义，存在即可
    }

    /// 失败或用户只要一次构建时删掉旗标，避免坏包循环。
    static func clearChain() {
        try? FileManager.default.removeItem(at: flagURL)
    }

    /// 转给无副作用的 AutoEvolutionPolicy，这里不重复写条件。
    static func shouldAutoStart(
        autoEvolutionEnabled: Bool,
        isChainActive: Bool,
        pendingCount: Int
    ) -> Bool {
        AutoEvolutionPolicy.shouldAutoStart(
            autoEvolutionEnabled: autoEvolutionEnabled,
            isChainActive: isChainActive,
            pendingCount: pendingCount
        )
    }
}

import AIBookEvolution
import Foundation

/// Self-evolution loop: optimization queue drives AI to change source, rebuild and relaunch.
enum SelfEvolution {
    static let capabilityLabel = "自我进化"
    static let shortcutHint = "⌘E"

    static let productDefinition: [String] = [
        "ai-book（AIBook）：辅助读书软件，左页阅读原文，右页讲解与 AI 进化",
        "Swift 实现，可连接大模型 API 或 Cursor 本地对话",
        "左页名著补充：识别节选并补全为完整篇章",
        "可新建或打开本地 .txt；重启后记住对话上下文",
        "ai-book 自我进化：AI 分析优化队列，点「进化」自动改码、打包重启并继续下一条",
    ]

    static func statusLabel(from queue: OptimizationQueue) -> String? {
        let pending = queue.items.filter { $0.status == .pending }
        guard !queue.items.isEmpty else { return nil }
        if pending.isEmpty {
            return "优化队列已全部完成"
        }
        if let next = queue.nextPending() {
            let title = next.title.count > 16 ? String(next.title.prefix(16)) + "…" : next.title
            if isAutoEvolutionEnabled, AutoEvolutionCoordinator.isChainActive {
                return "自动升级中 · 待 \(pending.count) 条 · 下一条 #\(next.number) \(title)"
            }
            return "待优化 \(pending.count) 条 · 下一条 #\(next.number) \(title)"
        }
        return nil
    }

    private static var isAutoEvolutionEnabled: Bool {
        if UserDefaults.standard.object(forKey: "aiBook.autoEvolutionEnabled") != nil {
            return UserDefaults.standard.bool(forKey: "aiBook.autoEvolutionEnabled")
        }
        return true
    }

    /// Swift 源码根目录（含 Package.swift），供进化改码与 build-and-install 使用。
    static func sourceProjectPath() -> String {
        sourceProjectDirectory()?.path ?? "未找到 ai-book 源码目录"
    }

    static var sourceProjectReady: Bool {
        sourceProjectDirectory() != nil
    }

    static func sourceProjectDirectory() -> URL? {
        for candidate in sourceProjectCandidates() {
            if CursorService.isSourceProject(at: candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func sourceProjectCandidates() -> [URL] {
        var candidates: [URL] = []
        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        candidates.append(current)
        candidates.append(current.appendingPathComponent("ai-book", isDirectory: true))

        if let cursorDefault = CursorService.defaultProjectDirectory() {
            candidates.append(cursorDefault)
        }

        if let resources = Bundle.main.resourceURL {
            var directory = resources
            for _ in 0 ..< 8 {
                candidates.append(directory)
                candidates.append(directory.appendingPathComponent("ai-book", isDirectory: true))
                directory.deleteLastPathComponent()
            }
        }

        var seen: Set<String> = []
        return candidates.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }
}

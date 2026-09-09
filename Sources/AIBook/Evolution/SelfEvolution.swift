import AIBookEvolution
import Foundation

/// Self-evolution loop: optimization queue drives AI to change source, rebuild and relaunch.
enum SelfEvolution {
    static let capabilityLabel = "自我进化"
    static let shortcutHint = BookKeyboardShortcuts.evolutionHint

    static let productDefinition: [String] = [
        "ai-book（AIBook）：辅助读书软件，左页阅读原文，右页讲解与 AI 进化",
        "Swift 实现；读书用 book 大模型，进化固定 Cursor SDK 本地 Agent",
        "左页名著补充：识别节选并补全为完整篇章",
        "可新建或打开本地 .txt；重启后记住对话上下文",
        "ai-book 自我进化：AI 分析优化队列，点「进化」自动改码、打包重启并继续下一条",
    ]

    /// 自我进化两阶段工作流（分析入队 → 进化改码），进化后端固定为 Cursor 本地 Agent。
    static let workflowSteps: [String] = [
        "分析优化：Cursor 只读探索源码，找出可改进点并写入优化队列（左页编号命令同步）",
        "进化改码：取下一条待办，Cursor Agent 改码、swift build 验证，完成后自动 build-and-install 重启",
        "自动升级（可选）：队列仍有待办时重启后继续下一条，直至全部完成",
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

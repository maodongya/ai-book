import AIBookEvolution
import Foundation

/// 自进化闭环：优化队列驱动 AI 改源码、构建并重启。这里只提供定义、状态文案和源码根定位。
enum SelfEvolution {
    static var capabilityLabel: String { BookL10n.string("evolution.capabilityLabel") }
    static let shortcutHint = BookKeyboardShortcuts.evolutionHint

    /// 写进进化提示词的产品定义，改定位要和 docs/产品 同步。
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

    /// 顶栏状态一句：全完成 / 自动升级中 / 还有几条待办。空队列返回 nil。
    static func statusLabel(from queue: OptimizationQueue) -> String? {
        let pending = queue.items.filter { $0.status == .pending }
        guard !queue.items.isEmpty else { return nil }
        if pending.isEmpty {
            return BookL10n.string("evolution.queue.allDone")
        }
        if let next = queue.nextPending() {
            let title = next.title.count > 16 ? String(next.title.prefix(16)) + "…" : next.title // 顶栏截断
            if isAutoEvolutionEnabled, AutoEvolutionCoordinator.isChainActive {
                return BookL10n.format("evolution.queue.autoUpgrading", pending.count, next.number, title)
            }
            return BookL10n.format("evolution.queue.pending", pending.count, next.number, title)
        }
        return nil
    }

    /// 设置里没写过这个键时默认开启自动升级。
    private static var isAutoEvolutionEnabled: Bool {
        if UserDefaults.standard.object(forKey: "aiBook.autoEvolutionEnabled") != nil {
            return UserDefaults.standard.bool(forKey: "aiBook.autoEvolutionEnabled")
        }
        return true
    }

    /// Swift 源码根目录（含 Package.swift），供进化改码与 build-and-install 使用。
    static func sourceProjectPath() -> String {
        sourceProjectDirectory()?.path ?? BookL10n.string("evolution.sourceNotFound")
    }

    static var sourceProjectReady: Bool {
        sourceProjectDirectory() != nil
    }

    /// 在候选路径里找第一处像源码根的目录。
    static func sourceProjectDirectory() -> URL? {
        for candidate in sourceProjectCandidates() {
            if CursorService.isSourceProject(at: candidate) {
                return candidate
            }
        }
        return nil
    }

    /// cwd、cwd/ai-book、Cursor 默认项目、从 bundle 往上爬。去重。
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
                directory.deleteLastPathComponent() // 从 .app 往仓库根爬
            }
        }

        var seen: Set<String> = []
        return candidates.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }
}

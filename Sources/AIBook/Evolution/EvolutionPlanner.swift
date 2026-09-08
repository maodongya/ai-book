import AIBookEvolution
import Foundation

/// Parses optimization queue items and builds self-evolution prompts.
enum EvolutionPlanner {
    struct Command: Identifiable, Equatable {
        let number: Int
        let text: String
        let isCompleted: Bool

        var id: Int { number }
    }

    static func buildEvolutionPrompt(
        queue: OptimizationQueue,
        pending: OptimizationItem,
        projectPath: String
    ) -> String {
        let queueSummary = queue.items
            .sorted { $0.number < $1.number }
            .map { item in
                let mark: String
                switch item.status {
                case .completed: mark = "✓"
                case .running: mark = "▶"
                case .skipped: mark = "—"
                case .pending: mark = "○"
                }
                return "\(mark) #\(item.number) \(item.title)"
            }
            .joined(separator: "\n")

        let suggestedFiles = pending.suggestedFiles.isEmpty
            ? "（未指定）"
            : pending.suggestedFiles.joined(separator: "\n")

        let definition = SelfEvolution.productDefinition
            .map { "- \($0)" }
            .joined(separator: "\n")

        return """
        【AIBook 产品定义】
        \(definition)

        【优化队列摘要】
        \(queueSummary.isEmpty ? "（队列为空）" : queueSummary)

        【当前待进化】
        - 编号：\(pending.number)
        - 标题：\(pending.title)
        - 理由：\(pending.rationale.isEmpty ? "（无）" : pending.rationale)
        - 类别：\(pending.category.rawValue)
        - 优先级：\(pending.priority.rawValue)
        - 风险：\(pending.risk.rawValue)
        - 建议文件：
        \(suggestedFiles)

        【源码目录】
        \(projectPath)
        （含 Package.swift、Sources/AIBook、scripts/build-and-install.sh；非 .app/Contents/Resources 安装包目录）

        【本次进化任务】
        1. 阅读 \(projectPath)/Sources/AIBook 与 cursor-bridge，先输出需求理解与影响范围分析
        2. 列出将检查/修改的文件清单及理由，再逐步改码（最小必要改动）
        3. 每步说明改动意图；充分使用 Read/Grep/Glob/Edit/Shell 等工具探索与验证
        4. 若涉及界面，保持现有书籍风格（BookTheme）
        5. 改码后总结：变更文件、关键 diff、测试建议、潜在风险
        6. 最后输出机器可解析完成块：
        <<<EVOLUTION_DONE>>>
        {"number": \(pending.number), "summary": "一句话摘要"}
        <<<END>>>
        也可降级使用格式：\(pending.number)、已完成：…
        7. 对话结束后应用会自动执行 scripts/build-and-install.sh 并重启；若开启自动升级，重启后继续下一条
        8. 改码后请运行 swift build 验证
        9. 不要 git commit / git push；不要修改 optimization-queue.json（由应用写入）
        """
    }

    static func parseCompletionSummary(from reply: String, number: Int) -> String? {
        EvolutionCompletionParser.summary(from: reply, number: number)
    }
}

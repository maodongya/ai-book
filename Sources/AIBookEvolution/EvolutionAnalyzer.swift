import Foundation

public enum EvolutionAnalyzer {
    public static let analysisSystemPrompt = """
    你是 AIBook 的优化分析器。只诊断，不改文件、不 apply diff、不运行会改动工作区的命令。
    最后必须输出 <<<OPTIMIZATION_QUEUE>>> JSON 数组 <<<END>>>。
    """

    public static let capabilityMap = """
    AIBook（ai-book）辅助读书 macOS 应用能力对照：
    - 左页：打开/编辑 .txt、选中文字、拖拽打开
    - 读书助手：讲解选中/全文、多轮追问、自动朗读
    - 翻译：逐字/整段翻译，右页可编辑保存
    - 名著补充：识别节选并补全篇章写回左页
    - 语音：系统 TTS / Edge 在线女声，多档引擎与语言处理
    - AI 进化：优化队列 + 改码 + 自动构建重启
    - 双后端：大模型 API（OpenAI 兼容）与 Cursor 本地 Agent
    - 设置：提供商、模型、Cursor Key、自动升级、语音

    优化优先级：用户可感知缺口（讲解看不见、入口过深、流程断裂）优先于重构、注释、重命名。
    已知 P0：读书助手 Tab 不展示讲解对话与流式输出，用户只能听不能看。
    """

    public static func buildAnalysisPrompt(
        queue: OptimizationQueue,
        projectPath: String,
        direction: String? = nil
    ) -> String {
        let pendingTitles = queue.items
            .filter { $0.status == .pending || $0.status == .running }
            .map { "#\($0.number) \($0.title)" }
            .joined(separator: "\n")
        let completedTitles = queue.items
            .filter { $0.status == .completed || $0.status == .skipped }
            .map { "#\($0.number) \($0.title)" }
            .joined(separator: "\n")
        let trimmedDirection = direction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let directionSection = trimmedDirection.isEmpty
            ? ""
            : """

        【用户指定方向】
        \(trimmedDirection)
        请优先围绕上述方向分析；仍须遵守只读、不改码、最多 8 条、不重复已有标题。
        """

        return """
        【任务】分析 AIBook 可优化之处，输出优化队列条目（只诊断，不改码）。
        \(directionSection)
        【产品定位】
        ai-book（AIBook）是一款 macOS 辅助读书应用：左页阅读原文，右页 AI 讲解、翻译与自我进化。

        【能力对照】
        \(capabilityMap)

        【已有队列 · 待办】
        \(pendingTitles.isEmpty ? "（无）" : pendingTitles)

        【已有队列 · 已完成/跳过】
        \(completedTitles.isEmpty ? "（无）" : completedTitles)

        【源码目录】
        \(projectPath)
        （含 Package.swift、Sources/AIBook、cursor-bridge、speech-bridge）

        【分析要求】
        1. 使用 read / grep / glob 只读探索源码，不要修改任何文件
        2. 对比能力对照与源码现状，找出用户可感知的改进点
        3. 每条包含 title、rationale、category、priority、risk、suggestedFiles
        4. category 取值：ux / featureGap / stability / performance / maintainability
        5. priority 取值：high / medium / low；risk 取值：low / medium / high
        6. 最多输出 8 条；不要重复已有队列标题（规范化后完全相等视为重复）
        7. 若无新优化点，输出空数组 []

        【输出格式】最后必须给出：
        <<<OPTIMIZATION_QUEUE>>>
        [
          {
            "title": "短标题",
            "rationale": "为何值得做",
            "category": "ux",
            "priority": "high",
            "risk": "medium",
            "suggestedFiles": ["Sources/AIBook/..."]
          }
        ]
        <<<END>>>
        """
    }

    public static func parseItems(from reply: String) -> [OptimizationDraft] {
        if let fenced = parseFencedJSON(from: reply), !fenced.isEmpty {
            return fenced
        }
        return parseNumberedFallback(from: reply)
    }

    private static func parseFencedJSON(from reply: String) -> [OptimizationDraft]? {
        let pattern = #"<<<OPTIMIZATION_QUEUE>>>\s*(\[[\s\S]*?\])\s*<<<END>>>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: reply,
                range: NSRange(reply.startIndex..., in: reply)
              ),
              let range = Range(match.range(at: 1), in: reply)
        else { return nil }

        guard let data = reply[range].data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }

        return array.compactMap { object in
            guard let title = object["title"] as? String else { return nil }
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty else { return nil }
            let rationale = (object["rationale"] as? String) ?? ""
            let category = OptimizationItem.Category(
                rawValue: (object["category"] as? String) ?? ""
            ) ?? .featureGap
            let priority = OptimizationItem.Priority(
                rawValue: (object["priority"] as? String) ?? ""
            ) ?? .medium
            let risk = OptimizationItem.Risk(
                rawValue: (object["risk"] as? String) ?? ""
            ) ?? .low
            let suggestedFiles = object["suggestedFiles"] as? [String] ?? []
            return OptimizationDraft(
                title: trimmedTitle,
                rationale: rationale,
                category: category,
                priority: priority,
                risk: risk,
                suggestedFiles: suggestedFiles
            )
        }
    }

    private static func parseNumberedFallback(from reply: String) -> [OptimizationDraft] {
        NumberedNoteParser.parse(reply)
            .filter { !$0.isCompleted }
            .map { command in
                OptimizationDraft(
                    title: command.title,
                    rationale: "",
                    category: .featureGap,
                    priority: .medium,
                    risk: .low,
                    suggestedFiles: []
                )
            }
    }
}

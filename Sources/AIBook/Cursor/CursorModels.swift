import Foundation

enum CursorModelOption: String, CaseIterable, Identifiable, Codable {
    case composer25 = "composer-2.5"
    case autoSmart = "auto-smart"
    case auto = "auto"
    case gpt4o = "gpt-4o"
    case claudeSonnet = "claude-sonnet-4"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .composer25: return "Composer 2.5"
        case .autoSmart: return "Cursor Router"
        case .auto: return "Auto"
        case .gpt4o: return "GPT-4o"
        case .claudeSonnet: return "Claude Sonnet"
        }
    }
}

enum CursorContextLimits {
    /// Approximate character budget for a single Cursor prompt (≈128k tokens).
    static let maxCharacters = 128_000
}

enum LLMContextLimits {
    /// Approximate character budget for a single LLM chat prompt (≈64k tokens).
    static let maxCharacters = 64_000
}

struct CursorContextUsage {
    let usedCharacters: Int
    let limitCharacters: Int
    let percentage: Double
    let fileCharacters: Int
    let fileTotalCharacters: Int
    let historyCharacters: Int
    let inputCharacters: Int
    let selectionCharacters: Int
    let promptCharacters: Int
    let usesSelectionAnchor: Bool

    var formattedUsed: String {
        formatCount(usedCharacters)
    }

    var formattedLimit: String {
        formatCount(limitCharacters)
    }

    private func formatCount(_ value: Int) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", Double(value) / 1000.0)
        }
        return "\(value)"
    }
}

enum CursorContextCalculator {
    static func usage(
        fileContent: String,
        selectedText: String,
        history: [ChatMessage],
        input: String,
        contextPercent: Double,
        limitCharacters: Int = CursorContextLimits.maxCharacters
    ) -> CursorContextUsage {
        let breakdown = promptBreakdown(
            fileContent: fileContent,
            selectedText: selectedText,
            history: history,
            input: input,
            contextPercent: contextPercent
        )

        let limit = limitCharacters
        let percentage = min(Double(breakdown.total) / Double(limit) * 100.0, 100.0)

        return CursorContextUsage(
            usedCharacters: breakdown.total,
            limitCharacters: limit,
            percentage: percentage,
            fileCharacters: breakdown.fileCharacters,
            fileTotalCharacters: fileContent.count,
            historyCharacters: breakdown.historyCharacters,
            inputCharacters: breakdown.inputCharacters,
            selectionCharacters: breakdown.selectionCharacters,
            promptCharacters: breakdown.promptCharacters,
            usesSelectionAnchor: breakdown.usesSelectionAnchor
        )
    }

    /// Excerpt sized by `percent` of full text. When `focus` is set, centers the window on that substring.
    static func excerpt(from content: String, percent: Double, focus: String? = nil) -> String {
        guard !content.isEmpty else { return "" }
        let clampedPercent = min(max(percent, 5), 100)
        let length = max(Int(Double(content.count) * clampedPercent / 100.0), 200)

        if let focus, !focus.isEmpty, let range = content.range(of: focus) {
            let startOffset = content.distance(from: content.startIndex, to: range.lowerBound)
            let center = startOffset + focus.count / 2
            var start = max(0, center - length / 2)
            let end = min(content.count, start + length)
            if end - start < length {
                start = max(0, end - length)
            }
            let startIndex = content.index(content.startIndex, offsetBy: start)
            let endIndex = content.index(content.startIndex, offsetBy: end)
            return String(content[startIndex ..< endIndex])
        }

        return String(content.prefix(length))
    }

    /// Mirrors `ReadingViewModel.buildChatPrompt` + Cursor history wrapping in explain.mjs.
    static func promptBreakdown(
        fileContent: String,
        selectedText: String,
        history: [ChatMessage],
        input: String,
        contextPercent: Double
    ) -> (
        fileCharacters: Int,
        historyCharacters: Int,
        inputCharacters: Int,
        selectionCharacters: Int,
        promptCharacters: Int,
        total: Int,
        usesSelectionAnchor: Bool
    ) {
        let focus = selectedText.isEmpty ? nil : selectedText
        let fileExcerpt = excerpt(from: fileContent, percent: contextPercent, focus: focus)
        let fileCharacters = fileExcerpt.count
        let usesSelectionAnchor = focus != nil && fileContent.contains(focus!)
        let selectionCharacters = selectedText.count
        let inputCharacters = input.count

        var sections: [String] = []
        if !fileContent.isEmpty {
            let percentLabel = Int(min(max(contextPercent, 5), 100))
            sections.append("【当前阅读文本节选（\(percentLabel)%）】\n\(fileExcerpt)")
        }
        if !selectedText.isEmpty {
            sections.append("【当前选中内容】\n\(selectedText)")
        }
        if !input.isEmpty {
            sections.append("【用户问题】\n\(input)")
        } else if sections.isEmpty {
            sections.append("【用户问题】\n…")
        }

        let promptCharacters = sections.joined(separator: "\n\n").count

        let conversationHistory = history.filter { message in
            guard message.role == .assistant else { return true }
            return !message.content.hasPrefix(BookL10n.string("vm.chat.legacyReadingHint"))
                && !BookL10nMarkers.isReadingAssistantWelcome(message.content)
        }

        var historyCharacters = 0
        if !conversationHistory.isEmpty {
            historyCharacters = conversationHistory.reduce(0) { partial, message in
                let roleLabel = message.role == .assistant ? "assistant" : "user"
                var size = roleLabel.count + 2 + message.content.count + 2
                if let thinking = message.thinking, !thinking.isEmpty {
                    size += thinking.count + 16
                }
                return partial + size
            }
        }

        let total = historyCharacters + promptCharacters
        return (
            fileCharacters,
            historyCharacters,
            inputCharacters,
            selectionCharacters,
            promptCharacters,
            total,
            usesSelectionAnchor
        )
    }
}

/// One step in a Cursor-style agent execution trace (tool call, subagent, etc.).
struct ExecutionStep: Identifiable, Equatable, Codable {
    enum Status: String, Codable {
        case running
        case completed
        case failed
    }

    let id: UUID
    let callId: String?
    let name: String
    let detail: String?
    var status: Status
    let startedAt: Date
    var completedAt: Date?
    var resultSummary: String?
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        callId: String? = nil,
        name: String,
        detail: String? = nil,
        status: Status = .running,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        resultSummary: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.callId = callId
        self.name = name
        self.detail = detail
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.resultSummary = resultSummary
        self.errorMessage = errorMessage
    }

    var displayLabel: String {
        EvolutionToolLabels.label(name: name, detail: detail)
    }

    var icon: String {
        EvolutionToolLabels.icon(for: name)
    }

    var durationLabel: String? {
        guard let completedAt else { return nil }
        let seconds = completedAt.timeIntervalSince(startedAt)
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        }
        return String(format: "%.1fs", seconds)
    }

    var hasExpandableDetail: Bool {
        let detailText = detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resultText = resultSummary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorText = errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !detailText.isEmpty || !resultText.isEmpty || !errorText.isEmpty
    }

    /// Primary input shown for this step (path, command, query, etc.).
    var inputPreview: String? {
        let trimmed = detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Absolute file path when the step targets a local file.
    var resolvedFilePath: String? {
        let lowered = name.lowercased()
        let isFileTool = lowered.contains("read")
            || lowered.contains("write")
            || lowered.contains("edit")
            || lowered.contains("delete")
            || lowered.contains("lint")
        guard isFileTool else { return nil }

        guard let candidate = Self.extractPathCandidate(from: detail) else { return nil }
        return Self.resolveProjectFilePath(candidate)
    }

    private static func extractPathCandidate(from detail: String?) -> String? {
        guard let detail, !detail.isEmpty else { return nil }

        let firstLine = detail
            .components(separatedBy: "\n").first?
            .components(separatedBy: " · ").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if looksLikeFilePath(firstLine) {
            return firstLine
        }

        if let brace = detail.firstIndex(of: "{"),
           let data = String(detail[brace...]).data(using: .utf8),
           let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let path = args["path"] as? String,
           looksLikeFilePath(path) {
            return path
        }

        return nil
    }

    private static func looksLikeFilePath(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") { return true }
        return trimmed.contains("/")
            || trimmed.hasSuffix(".swift")
            || trimmed.hasSuffix(".txt")
            || trimmed.hasSuffix(".mjs")
            || trimmed.hasSuffix(".sh")
    }

    private static func resolveProjectFilePath(_ candidate: String) -> String? {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            let expanded = (trimmed as NSString).expandingTildeInPath
            return FileManager.default.fileExists(atPath: expanded) ? expanded : expanded
        }

        if let root = SelfEvolution.sourceProjectDirectory() {
            let resolved = root.appendingPathComponent(trimmed).standardizedFileURL.path
            if FileManager.default.fileExists(atPath: resolved) {
                return resolved
            }
        }

        return trimmed.contains("/") ? trimmed : nil
    }

    var hasFileRevealAction: Bool {
        guard let path = resolvedFilePath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }
}

enum EvolutionToolLabels {
    static func icon(for name: String) -> String {
        let lowered = name.lowercased()
        if lowered.contains("read") { return "doc.text" }
        if lowered.contains("grep") || lowered.contains("search") { return "magnifyingglass" }
        if lowered.contains("glob") || lowered.contains("list") { return "folder" }
        if lowered.contains("write") || lowered.contains("edit") || lowered.contains("strreplace") { return "pencil" }
        if lowered.contains("shell") || lowered.contains("terminal") { return "terminal" }
        if lowered.contains("task") || lowered.contains("agent") { return "person.2" }
        if lowered.contains("todo") || lowered.contains("plan") { return "checklist" }
        if lowered.contains("delete") { return "trash" }
        return "wrench.and.screwdriver"
    }

    static func label(name: String, detail: String?) -> String {
        let base = localizedToolName(name)
        guard let detail, !detail.isEmpty else { return base }
        let trimmed = detail.count > 120 ? String(detail.prefix(117)) + "…" : detail
        return "\(base) · \(trimmed)"
    }

    static func localizedToolName(_ name: String) -> String {
        switch name.lowercased() {
        case "read", "read_file": return "读取文件"
        case "write", "write_file": return "写入文件"
        case "edit", "strreplace", "search_replace": return "编辑文件"
        case "grep": return "搜索代码"
        case "glob", "glob_file_search": return "查找文件"
        case "shell", "run_terminal_cmd": return "运行命令"
        case "semsearch", "semanticsearch", "codebase_search": return "语义搜索"
        case "task": return "启动子任务"
        case "update_todos", "todowrite": return "更新待办"
        case "delete": return "删除文件"
        case "read_lints": return "检查 Lint"
        case "websearch", "web_search": return "网络搜索"
        case "generateimage", "generate_image": return "生成图片"
        case "switchmode", "switch_mode": return "切换模式"
        case "mcp_call_tool", "mcp_get_tools", "mcp_fetch_resource", "mcp_auth": return "MCP 工具"
        case "await": return "等待后台任务"
        default:
            if name.lowercased().hasPrefix("mcp_") { return "MCP 工具" }
            return name
        }
    }
}

enum CursorStreamEvent {
    case thinkingDelta(String)
    case textDelta(String)
    case statusUpdate(String)
    case toolUpdate(
        name: String,
        status: String,
        callId: String?,
        detail: String?,
        result: String?,
        error: String?
    )
    case done(text: String, thinking: String?)
    case error(String)
}

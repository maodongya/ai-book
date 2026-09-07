import Foundation

/// Self-evolution loop: read left-page numbered commands, drive AI to change source, rebuild and relaunch.
enum SelfEvolution {
    static let capabilityLabel = "自我进化"
    static let shortcutHint = "⌘E"

    static let productDefinition: [String] = [
        "ai-book（AIBook）：辅助读书软件，左页原文/命令笔记（可编辑），右页讲解（与左页选中或全文相关）",
        "Swift 实现，可连接大模型 API 或 Cursor 本地对话",
        "左页名著补充：识别节选并补全为完整篇章",
        "可新建或打开本地 .txt；重启后记住对话上下文",
        "ai-book 自我进化：左页编号命令自动升级（无需手动点进化），完成后自动打包重启并继续下一条",
    ]

    struct Status: Equatable {
        let pendingCount: Int
        let totalCount: Int
        let nextCommand: EvolutionPlanner.Command?
    }

    static func status(from content: String) -> Status {
        let commands = EvolutionPlanner.parseCommands(from: content)
        let pending = commands.filter { !$0.isCompleted }
        return Status(
            pendingCount: pending.count,
            totalCount: commands.count,
            nextCommand: pending.first
        )
    }

    static func statusLabel(from content: String) -> String? {
        let status = status(from: content)
        guard status.totalCount > 0 else { return nil }
        if status.pendingCount == 0 {
            return "命令已全部完成 · 将自动重启"
        }
        if isAutoEvolutionEnabled {
            if let next = status.nextCommand {
                return "自动升级中 · 待 \(status.pendingCount) 条 · 下一条 第 \(next.number) 条"
            }
        }
        if let next = status.nextCommand {
            return "待进化 \(status.pendingCount) 条 · 下一条 第 \(next.number) 条"
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

    /// Pulls a「编号、已完成：…」line from the assistant reply and merges it into readme notes.
    static func applyCompletionFromReply(
        _ reply: String,
        to content: String,
        expectedNumber: Int
    ) -> String? {
        let lines = reply.components(separatedBy: .newlines)
        let prefix = "\(expectedNumber)、"
        let completedPrefix = "\(expectedNumber)、已完成"

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(prefix) || trimmed.hasPrefix(completedPrefix) else { continue }
            guard trimmed.contains("已完成") else { continue }
            return mergeCompletionLine(trimmed, into: content, number: expectedNumber)
        }

        return nil
    }

    static func markCompleted(
        in content: String,
        number: Int,
        summary: String
    ) -> String {
        let line = "\(number)、已完成：\(summary)"
        return mergeCompletionLine(line, into: content, number: number) ?? content
    }

    private static func mergeCompletionLine(
        _ completionLine: String,
        into content: String,
        number: Int
    ) -> String? {
        var lines = content.components(separatedBy: .newlines)
        let prefix = "\(number)、"
        var replaced = false

        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(prefix) else { continue }
            lines[index] = completionLine
            replaced = true
            break
        }

        if !replaced {
            lines.append(completionLine)
        }

        return lines.joined(separator: "\n")
    }
}

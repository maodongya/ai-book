import Foundation

/// Parses numbered command lines from the left-page readme notes and builds self-evolution prompts.
enum EvolutionPlanner {
    struct Command: Identifiable, Equatable {
        let number: Int
        let text: String
        let isCompleted: Bool

        var id: Int { number }
    }

    static func parseCommands(from content: String) -> [Command] {
        let lines = content.components(separatedBy: .newlines)
        var commands: [Command] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            guard let number = leadingCommandNumber(in: trimmed) else { continue }

            let isCompleted = isCommandCompleted(trimmed)

            commands.append(Command(number: number, text: trimmed, isCompleted: isCompleted))
        }

        return commands.sorted { $0.number < $1.number }
    }

    static func nextPending(from content: String) -> Command? {
        parseCommands(from: content).first { !$0.isCompleted }
    }

    static func buildEvolutionPrompt(
        allCommands: [Command],
        pending: Command,
        projectPath: String
    ) -> String {
        let commandList = allCommands
            .map { entry in
                let mark = entry.isCompleted ? "✓" : "○"
                return "\(mark) \(entry.text)"
            }
            .joined(separator: "\n")

        let definition = SelfEvolution.productDefinition
            .map { "- \($0)" }
            .joined(separator: "\n")

        return """
        【AIBook 产品定义】
        \(definition)

        【左页全部命令】
        \(commandList)

        【当前待进化（第 \(pending.number) 条）】
        \(pending.text)

        【源码目录】
        \(projectPath)
        （含 Package.swift、Sources/AIBook、scripts/build-and-install.sh；非 .app/Contents/Resources 安装包目录）

        【本次进化任务】
        1. 阅读 \(projectPath)/Sources/AIBook 与 cursor-bridge，先输出需求理解与影响范围分析
        2. 列出将检查/修改的文件清单及理由，再逐步改码（最小必要改动）
        3. 每步说明改动意图；充分使用 Read/Grep/Glob/Edit/Shell 等工具探索与验证
        4. 若涉及界面，保持现有书籍风格（BookTheme）
        5. 改码后总结：变更文件、关键 diff、测试建议、潜在风险
        6. 最后给出可写入左页 readme 的一行「已完成」摘要（格式：\(pending.number)、已完成：…）
        7. 对话结束后应用会自动执行 scripts/build-and-install.sh 并重启；若开启自动升级，重启后继续下一条
        8. 改码后请运行 swift build 验证
        """
    }

    /// Treats lines ending with「（已经完成）」or containing other completion markers as done.
    private static func isCommandCompleted(_ line: String) -> Bool {
        if line.contains("已完成") { return true }
        if line.contains("已修复") { return true }
        if line.contains("已实现") { return true }
        if line.localizedCaseInsensitiveContains("done") { return true }
        if line.hasSuffix("（已经完成）") || line.hasSuffix("(已经完成)") { return true }
        return false
    }

    private static func leadingCommandNumber(in line: String) -> Int? {
        var digits = ""
        for character in line {
            if character.isNumber {
                digits.append(character)
            } else if character == "、" || character == "." {
                break
            } else if !digits.isEmpty {
                break
            } else {
                return nil
            }
        }
        guard !digits.isEmpty, let number = Int(digits) else { return nil }
        return number
    }
}

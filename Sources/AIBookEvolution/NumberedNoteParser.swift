import Foundation

public struct ParsedNoteCommand: Equatable {
    public let number: Int
    public let title: String
    public let isCompleted: Bool

    public init(number: Int, title: String, isCompleted: Bool) {
        self.number = number
        self.title = title
        self.isCompleted = isCompleted
    }
}

public enum NumberedNoteParser {
    public static func parse(_ content: String) -> [ParsedNoteCommand] {
        let lines = content.components(separatedBy: .newlines)
        var commands: [ParsedNoteCommand] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let number = leadingCommandNumber(in: trimmed) else { continue }

            let isCompleted = isCommandCompleted(trimmed)
            let title = extractTitle(from: trimmed, number: number, isCompleted: isCompleted)
            commands.append(ParsedNoteCommand(number: number, title: title, isCompleted: isCompleted))
        }

        return commands.sorted { $0.number < $1.number }
    }

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

    private static func extractTitle(from line: String, number: Int, isCompleted: Bool) -> String {
        var title = line
        if let range = title.range(of: #"^\d+[、.]\s*"#, options: .regularExpression) {
            title.removeSubrange(range)
        }
        for prefix in ["已完成：", "已完成:", "已修复：", "已修复:", "已实现：", "已实现:"] {
            if title.hasPrefix(prefix) {
                title = String(title.dropFirst(prefix.count))
                break
            }
        }
        return title.trimmingCharacters(in: .whitespaces)
    }
}

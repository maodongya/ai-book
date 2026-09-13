import Foundation

/// 将优化队列格式化为左页命令笔记的编号行文本（与 `NumberedNoteParser` 互逆）。
public enum NumberedNoteFormatter {
    /// 按编号排序后一行一条，中间用换行。
    public static func format(_ queue: OptimizationQueue) -> String {
        queue.items
            .sorted { $0.number < $1.number }
            .map(formatItem)
            .joined(separator: "\n")
    }

    /// 完成态补「已完成：」，已有标记则不叠；跳过加括号前缀。
    private static func formatItem(_ item: OptimizationItem) -> String {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        switch item.status {
        case .completed:
            if hasCompletionMarker(in: title) {
                return "\(item.number)、\(title)" // 标题里已有完成语义
            }
            return "\(item.number)、已完成：\(title)"
        case .skipped:
            return "\(item.number)、（已跳过）\(title)"
        case .running, .pending:
            return "\(item.number)、\(title)" // 进行中不写状态词，留给解析当 pending
        }
    }

    /// 标题是否已经声明完成，避免「已完成：已完成：…」。
    private static func hasCompletionMarker(in title: String) -> Bool {
        if title.hasPrefix("已完成") || title.hasPrefix("已修复") || title.hasPrefix("已实现") {
            return true
        }
        if title.hasSuffix("（已经完成）") || title.hasSuffix("(已经完成)") {
            return true
        }
        return title.localizedCaseInsensitiveContains("done")
    }
}

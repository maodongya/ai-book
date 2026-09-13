import Foundation

/// 优化队列里的一条待办。id 稳定，number 给人看的编号。
public struct OptimizationItem: Identifiable, Codable, Equatable {
    /// 分析分类。rawValue 已入队列 JSON。
    public enum Category: String, Codable, CaseIterable {
        case ux
        case featureGap
        case stability
        case performance
        case maintainability
    }

    /// 排队优先级。nextPending 先看这个。
    public enum Priority: String, Codable, CaseIterable {
        case high
        case medium
        case low

        /// 排序用：高优先数字小。
        public var rank: Int {
            switch self {
            case .high: return 0
            case .medium: return 1
            case .low: return 2
            }
        }
    }

    /// 改动风险，给排序和提示。
    public enum Risk: String, Codable, CaseIterable {
        case low
        case medium
        case high
    }

    /// user=笔记/手加；analysis=模型草稿。
    public enum Source: String, Codable {
        case ai
        case user
    }

    /// 同时只允许一条 running。
    public enum Status: String, Codable {
        case pending
        case running
        case completed
        case skipped
    }

    public let id: UUID
    public var number: Int // 左页「N、」编号，不是 UUID
    public var title: String
    public var rationale: String
    public var category: Category
    public var priority: Priority
    public var risk: Risk
    public var suggestedFiles: [String]
    public var source: Source
    public var status: Status
    public var pinnedAt: Date? // 置顶时间，nil 不置顶
    public var createdAt: Date
    public var updatedAt: Date
    public var completionSummary: String?

    /// 去空白并统一标点，用来判重，不拿来展示。
    public static func normalizedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let squeezed = trimmed.replacingOccurrences(
            of: "\\s+",
            with: "",
            options: .regularExpression
        )
        return squeezed
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: "；", with: ";")
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "、", with: ",")
    }
}

/// 入队前的草稿，还没有 id / number / 状态。
public struct OptimizationDraft: Equatable {
    public var title: String
    public var rationale: String
    public var category: OptimizationItem.Category
    public var priority: OptimizationItem.Priority
    public var risk: OptimizationItem.Risk
    public var suggestedFiles: [String]

    public init(
        title: String,
        rationale: String,
        category: OptimizationItem.Category,
        priority: OptimizationItem.Priority,
        risk: OptimizationItem.Risk,
        suggestedFiles: [String]
    ) {
        self.title = title
        self.rationale = rationale
        self.category = category
        self.priority = priority
        self.risk = risk
        self.suggestedFiles = suggestedFiles
    }
}

/// 一次 AI 分析合并进队列的计数，给用户看「发现/入队/去重」。
public struct MergeReport: Equatable {
    public var discovered: Int
    public var enqueued: Int
    public var duplicatesSkipped: Int
    public var truncated: Int // 因上限没能入队的条数

    public init(discovered: Int, enqueued: Int, duplicatesSkipped: Int, truncated: Int) {
        self.discovered = discovered
        self.enqueued = enqueued
        self.duplicatesSkipped = duplicatesSkipped
        self.truncated = truncated
    }

    public var summaryChinese: String {
        "发现 \(discovered) 条，入队 \(enqueued) 条，去重跳过 \(duplicatesSkipped) 条"
            + (truncated > 0 ? "，另有 \(truncated) 条因上限未入队" : "")
    }
}

import Foundation

public struct OptimizationItem: Identifiable, Codable, Equatable {
    public enum Category: String, Codable, CaseIterable {
        case ux
        case featureGap
        case stability
        case performance
        case maintainability
    }

    public enum Priority: String, Codable, CaseIterable {
        case high
        case medium
        case low

        public var rank: Int {
            switch self {
            case .high: return 0
            case .medium: return 1
            case .low: return 2
            }
        }
    }

    public enum Risk: String, Codable, CaseIterable {
        case low
        case medium
        case high
    }

    public enum Source: String, Codable {
        case ai
        case user
    }

    public enum Status: String, Codable {
        case pending
        case running
        case completed
        case skipped
    }

    public let id: UUID
    public var number: Int
    public var title: String
    public var rationale: String
    public var category: Category
    public var priority: Priority
    public var risk: Risk
    public var suggestedFiles: [String]
    public var source: Source
    public var status: Status
    public var pinnedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var completionSummary: String?

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

public struct MergeReport: Equatable {
    public var discovered: Int
    public var enqueued: Int
    public var duplicatesSkipped: Int
    public var truncated: Int

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

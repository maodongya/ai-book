import Foundation

public struct OptimizationQueue: Codable, Equatable {
    public var version: Int
    public var updatedAt: Date
    public var lastAnalysisAt: Date?
    public var items: [OptimizationItem]

    public init(
        version: Int,
        updatedAt: Date,
        lastAnalysisAt: Date?,
        items: [OptimizationItem]
    ) {
        self.version = version
        self.updatedAt = updatedAt
        self.lastAnalysisAt = lastAnalysisAt
        self.items = items
    }

    public static var empty: OptimizationQueue {
        OptimizationQueue(version: 1, updatedAt: Date(), lastAnalysisAt: nil, items: [])
    }

    public func nextPending() -> OptimizationItem? {
        let pending = items.filter { $0.status == .pending }
        let pinned = pending
            .filter { $0.pinnedAt != nil }
            .sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
        if let firstPinned = pinned.first { return firstPinned }
        return pending.sorted {
            if $0.priority.rank != $1.priority.rank { return $0.priority.rank < $1.priority.rank }
            return $0.number < $1.number
        }.first
    }

    public mutating func merge(drafts: [OptimizationDraft], maxNewItems: Int = 8) -> MergeReport {
        let existingKeys = Set(items.map { OptimizationItem.normalizedTitle($0.title) })
        var duplicates = 0
        var accepted: [OptimizationDraft] = []
        for draft in drafts {
            let key = OptimizationItem.normalizedTitle(draft.title)
            if key.isEmpty
                || existingKeys.contains(key)
                || accepted.contains(where: { OptimizationItem.normalizedTitle($0.title) == key }) {
                duplicates += 1
                continue
            }
            accepted.append(draft)
        }
        let truncated = max(0, accepted.count - maxNewItems)
        let toAdd = Array(accepted.prefix(maxNewItems))
        var nextNumber = (items.map(\.number).max() ?? 0) + 1
        let now = Date()
        for draft in toAdd {
            items.append(
                OptimizationItem(
                    id: UUID(),
                    number: nextNumber,
                    title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    rationale: draft.rationale,
                    category: draft.category,
                    priority: draft.priority,
                    risk: draft.risk,
                    suggestedFiles: draft.suggestedFiles,
                    source: .ai,
                    status: .pending,
                    pinnedAt: nil,
                    createdAt: now,
                    updatedAt: now,
                    completionSummary: nil
                )
            )
            nextNumber += 1
        }
        updatedAt = now
        lastAnalysisAt = now
        return MergeReport(
            discovered: drafts.count,
            enqueued: toAdd.count,
            duplicatesSkipped: duplicates,
            truncated: truncated
        )
    }

    public mutating func markRunning(id: UUID) -> Bool {
        guard items.contains(where: { $0.status == .running }) == false else { return false }
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].status == .pending else {
            return false
        }
        items[index].status = .running
        items[index].updatedAt = Date()
        updatedAt = Date()
        return true
    }

    public mutating func markCompleted(id: UUID, summary: String) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].status == .running else {
            return false
        }
        items[index].status = .completed
        items[index].completionSummary = summary
        items[index].updatedAt = Date()
        updatedAt = Date()
        return true
    }

    public mutating func revertRunningToPending(id: UUID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].status == .running else {
            return false
        }
        items[index].status = .pending
        items[index].updatedAt = Date()
        updatedAt = Date()
        return true
    }

    public mutating func skip(id: UUID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].status == .pending else {
            return false
        }
        items[index].status = .skipped
        items[index].updatedAt = Date()
        updatedAt = Date()
        return true
    }

    public mutating func restore(id: UUID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].status == .skipped else {
            return false
        }
        items[index].status = .pending
        items[index].updatedAt = Date()
        updatedAt = Date()
        return true
    }

    public mutating func pin(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].pinnedAt = Date()
        items[index].priority = .high
        items[index].updatedAt = Date()
        updatedAt = Date()
    }

    @discardableResult
    public mutating func addUserItem(title: String) -> OptimizationItem {
        let now = Date()
        let item = OptimizationItem(
            id: UUID(),
            number: (items.map(\.number).max() ?? 0) + 1,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            rationale: "",
            category: .featureGap,
            priority: .medium,
            risk: .low,
            suggestedFiles: [],
            source: .user,
            status: .pending,
            pinnedAt: nil,
            createdAt: now,
            updatedAt: now,
            completionSummary: nil
        )
        items.append(item)
        updatedAt = now
        return item
    }

    public mutating func updateTitle(id: UUID, title: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        items[index].updatedAt = Date()
        updatedAt = Date()
    }

    public mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
        updatedAt = Date()
    }
}

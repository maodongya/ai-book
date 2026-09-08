# AIBook 进化功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 AI 只读分析 AIBook 可优化点并写入独立优化队列，用户再点「进化」逐条改码、构建、重启自动升级。

**Architecture:** 新增 Foundation 库 `AIBookEvolution` 作为队列与分析解析的唯一真源；App 的 `ReadingViewModel` 编排「分析」与「进化」两条互斥任务。分析走只读工具且不重启；进化复用现有 Cursor / LLM Agent 与 `AppRelauncher`，但数据源从左页 `fileContent` 改为 `optimization-queue.json`。

**Tech Stack:** Swift 5.9、SwiftUI、XCTest、Swift Package Manager、macOS 13+、现有 `LLMEvolutionAgent` / `CursorService` / `EvolutionLocalTools`。

**Spec:** [aibook进化设计.md](./aibook进化设计.md)

## Global Constraints

- 分析只诊断，不升级：分析阶段禁止 `edit` / `write` 源码，禁止构建重启。
- 队列是分析的结果，不是阅读原文：运行时不得再解析左页 `fileContent` 作为进化命令。
- 升级必须由「进化」按钮触发：点分析不等于改码。
- `AutoEvolutionCoordinator.markChainActive()` 只在 `startEvolution()` 成功开始执行时调用。
- `scheduleAutoEvolutionIfNeeded()` 必须同时满足：开关开、`isChainActive`、存在 pending。
- 单次分析最多写入 8 条；去重为标题规范化后完全相等。
- 同一时刻最多一条 `running`；分析与进化互斥。
- 不自动 `git commit` / `git push`。
- 平台：macOS 13+；语言：Swift 5.9；UI 保持 BookTheme 书籍风格。
- 用户可见文案用中文。

---

## File Structure

| 路径 | 职责 |
|------|------|
| `Sources/AIBookEvolution/OptimizationModels.swift` | `OptimizationItem`、枚举、`OptimizationDraft`、`MergeReport`、标题规范化 |
| `Sources/AIBookEvolution/OptimizationQueue.swift` | 队列状态机、`nextPending()`、`merge` |
| `Sources/AIBookEvolution/NumberedNoteParser.swift` | 从 readme 笔记解析编号行（仅迁移用） |
| `Sources/AIBookEvolution/OptimizationQueueStore.swift` | JSON 读写；可注入 `fileURL` |
| `Sources/AIBookEvolution/EvolutionAnalyzer.swift` | 分析 Prompt、JSON/编号降级解析、`capabilityMap` |
| `Sources/AIBookEvolution/EvolutionToolPolicy.swift` | 只读 vs 可变工具名判定 |
| `Tests/AIBookEvolutionTests/*.swift` | 上述库的 XCTest |
| `Package.swift` | 增加 library + testTarget；executable 依赖 library |
| `Sources/AIBook/Evolution/EvolutionPlanner.swift` | 改为基于 `OptimizationItem` 构建进化 Prompt |
| `Sources/AIBook/Evolution/SelfEvolution.swift` | 状态文案改为读队列 |
| `Sources/AIBook/Evolution/AutoEvolutionCoordinator.swift` | 自动升级必须 `isChainActive` |
| `Sources/AIBook/Evolution/EvolutionLocalTools.swift` | `allowMutations`；拒绝分析期可变工具 |
| `Sources/AIBook/LLM/LLMEvolutionAgent.swift` | `allowMutations`、`maxIterations` 覆盖 |
| `Sources/AIBook/Reading/ReadingViewModel.swift` | 队列发布、分析/进化编排、完成写回 Store |
| `Sources/AIBook/Evolution/EvolutionExecutionViews.swift` | 「分析优化」按钮；队列列表与操作 |
| `Sources/AIBook/Reading/ExplanationChatView.swift` | 把队列与回调传给面板 |
| `Sources/AIBook/Reading/ContentView.swift` | 胶囊/帮助文案 |
| `Sources/AIBook/Evolution/EvolutionAssistant.swift` | 欢迎语：先分析再进化 |
| `Sources/AIBook/Core/AIBookProduct.swift` | about 文案 |
| `Sources/AIBook/UI/SettingsView.swift` | 自动升级说明 |
| `整体功能文档设计.md` / `整体UI文档设计.md` | 与实现同步 |

不要把 `LLMEvolutionAgent` 的改码主循环拆到 Task 1–6。不要在本计划做读书助手对话区修复（那是分析可能提出的优化项，不是本功能本身）。

---

### Task 1: AIBookEvolution 库与队列领域模型

**Files:**
- Modify: `Package.swift`
- Create: `Sources/AIBookEvolution/OptimizationModels.swift`
- Create: `Sources/AIBookEvolution/OptimizationQueue.swift`
- Create: `Tests/AIBookEvolutionTests/OptimizationQueueTests.swift`

**Interfaces:**
- Consumes: 无
- Produces:
  - `public struct OptimizationItem: Identifiable, Codable, Equatable`
  - `public struct OptimizationDraft: Equatable`
  - `public struct MergeReport: Equatable`
  - `public struct OptimizationQueue: Codable, Equatable`
  - `OptimizationQueue.nextPending() -> OptimizationItem?`
  - `OptimizationQueue.merge(drafts:maxNewItems:) -> MergeReport`
  - `OptimizationQueue.markRunning/markCompleted/revertRunningToPending/skip/restore/pin/addUserItem/updateTitle/remove(id:)`
  - `OptimizationItem.normalizedTitle(_:) -> String`

- [ ] **Step 1: 增加 SPM library 与测试 target**

把 `Package.swift` 改为：

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIBook",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "AIBook", targets: ["AIBook"]),
        .library(name: "AIBookEvolution", targets: ["AIBookEvolution"]),
    ],
    targets: [
        .target(
            name: "AIBookEvolution",
            path: "Sources/AIBookEvolution"
        ),
        .executableTarget(
            name: "AIBook",
            dependencies: ["AIBookEvolution"],
            path: "Sources/AIBook",
            resources: [
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "AIBookEvolutionTests",
            dependencies: ["AIBookEvolution"],
            path: "Tests/AIBookEvolutionTests"
        ),
    ]
)
```

在 `Sources/AIBookEvolution` 放一个空的 `Placeholder.swift`（`public enum AIBookEvolutionModule {}`）以便现在就能解析包。

- [ ] **Step 2: 写失败测试**

创建 `Tests/AIBookEvolutionTests/OptimizationQueueTests.swift`：

```swift
import XCTest
@testable import AIBookEvolution

final class OptimizationQueueTests: XCTestCase {
    func testNormalizedTitleUnifiesWhitespaceAndChinesePunctuation() {
        XCTAssertEqual(
            OptimizationItem.normalizedTitle("  读书助手，展示讲解。  "),
            "读书助手,展示讲解."
        )
    }

    func testNextPendingPrefersPinnedThenHighPriorityThenNumber() {
        var queue = OptimizationQueue.empty
        let lowEarly = makeItem(number: 1, priority: .low)
        let highLate = makeItem(number: 3, priority: .high)
        let medium = makeItem(number: 2, priority: .medium)
        queue.items = [lowEarly, medium, highLate]
        XCTAssertEqual(queue.nextPending()?.number, 3)

        queue.pin(id: lowEarly.id)
        XCTAssertEqual(queue.nextPending()?.id, lowEarly.id)
    }

    func testMergeDedupsExactNormalizedTitleAndCapsAtEight() {
        var queue = OptimizationQueue.empty
        queue.items = [makeItem(number: 1, title: "修复朗读")]
        let drafts = (1...10).map { index in
            OptimizationDraft(
                title: index == 1 ? "修复朗读" : "新优化\(index)",
                rationale: "理由",
                category: .ux,
                priority: .medium,
                risk: .low,
                suggestedFiles: []
            )
        }
        let report = queue.merge(drafts: drafts, maxNewItems: 8)
        XCTAssertEqual(report.discovered, 10)
        XCTAssertEqual(report.duplicatesSkipped, 1)
        XCTAssertEqual(report.enqueued, 8)
        XCTAssertEqual(report.truncated, 1)
        XCTAssertEqual(queue.items.filter { $0.status == .pending }.count, 9)
        XCTAssertEqual(queue.items.map(\.number).max(), 9)
    }

    func testMarkRunningRejectsSecondItemAndCompletedCannotRun() {
        var queue = OptimizationQueue.empty
        let first = makeItem(number: 1)
        let second = makeItem(number: 2)
        queue.items = [first, second]
        XCTAssertTrue(queue.markRunning(id: first.id))
        XCTAssertFalse(queue.markRunning(id: second.id))
        XCTAssertTrue(queue.markCompleted(id: first.id, summary: "完成"))
        XCTAssertFalse(queue.markRunning(id: first.id))
        XCTAssertTrue(queue.revertRunningToPending(id: second.id) == false)
        _ = queue.markRunning(id: second.id)
        XCTAssertTrue(queue.revertRunningToPending(id: second.id))
        XCTAssertEqual(queue.items.first { $0.id == second.id }?.status, .pending)
    }

    private func makeItem(
        number: Int,
        title: String = "标题",
        priority: OptimizationItem.Priority = .medium
    ) -> OptimizationItem {
        OptimizationItem(
            id: UUID(),
            number: number,
            title: title,
            rationale: "",
            category: .ux,
            priority: priority,
            risk: .low,
            suggestedFiles: [],
            source: .user,
            status: .pending,
            pinnedAt: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            completionSummary: nil
        )
    }
}
```

规范化规则写死为：`trimming` → 连续空白压成一个空格再去掉全部空格 → 中文标点 `，。；：、` 换成 `,.;:,`（顿号换成逗号）。测试里 `"读书助手，展示讲解。"` 变为 `"读书助手,展示讲解."`。

- [ ] **Step 3: 运行测试确认失败**

Run: `swift test --filter OptimizationQueueTests -v`

Expected: FAIL，模块缺少 `OptimizationItem` / `OptimizationQueue`。

- [ ] **Step 4: 实现最小领域模型**

`OptimizationModels.swift` 必须包含：

```swift
import Foundation

public struct OptimizationItem: Identifiable, Codable, Equatable {
    public enum Category: String, Codable, CaseIterable {
        case ux, featureGap, stability, performance, maintainability
    }
    public enum Priority: String, Codable, CaseIterable {
        case high, medium, low
        public var rank: Int {
            switch self {
            case .high: return 0
            case .medium: return 1
            case .low: return 2
            }
        }
    }
    public enum Risk: String, Codable, CaseIterable { case low, medium, high }
    public enum Source: String, Codable { case ai, user }
    public enum Status: String, Codable { case pending, running, completed, skipped }

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
```

`OptimizationQueue.swift` 实现：

```swift
import Foundation

public struct OptimizationQueue: Codable, Equatable {
    public var version: Int
    public var updatedAt: Date
    public var lastAnalysisAt: Date?
    public var items: [OptimizationItem]

    public static var empty: OptimizationQueue {
        OptimizationQueue(version: 1, updatedAt: Date(), lastAnalysisAt: nil, items: [])
    }

    public func nextPending() -> OptimizationItem? {
        let pending = items.filter { $0.status == .pending }
        let pinned = pending.filter { $0.pinnedAt != nil }
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
            if key.isEmpty || existingKeys.contains(key)
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
```

删除 `Placeholder.swift`。

- [ ] **Step 5: 运行测试确认通过**

Run: `swift test --filter OptimizationQueueTests -v`

Expected: PASS。`testMergeDedupsExactNormalizedTitleAndCapsAtEight`：原有 1 条 + 入队 8 条 = 9 条 pending（草稿里第 1 条与已有「修复朗读」重复被跳过，2…10 共 9 条候选，截断 1 条，入队 8）。

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/AIBookEvolution Tests/AIBookEvolutionTests
git commit -m "$(cat <<'EOF'
feat: add optimization queue domain model

Independent queue types so evolution no longer depends on left-page text.
EOF
)"
```

---

### Task 2: 队列 JSON 存储与 readme 一次性迁移

**Files:**
- Create: `Sources/AIBookEvolution/NumberedNoteParser.swift`
- Create: `Sources/AIBookEvolution/OptimizationQueueStore.swift`
- Create: `Tests/AIBookEvolutionTests/OptimizationQueueStoreTests.swift`
- Test: `Tests/AIBookEvolutionTests/NumberedNoteParserTests.swift`

**Interfaces:**
- Consumes: `OptimizationQueue` / `OptimizationItem`（Task 1）
- Produces:
  - `NumberedNoteParser.parse(_:) -> [ParsedNoteCommand]`
  - `OptimizationQueueStore.init(fileURL:)`
  - `OptimizationQueueStore.load() throws -> OptimizationQueue`
  - `OptimizationQueueStore.save(_:) throws`
  - `OptimizationQueueStore.migrateFromReadmeNotesIfNeeded(_ notes: String) throws -> OptimizationQueue`
  - `OptimizationQueueStore.defaultFileURL: URL`

- [ ] **Step 1: 写失败测试**

`NumberedNoteParserTests.swift`：

```swift
import XCTest
@testable import AIBookEvolution

final class NumberedNoteParserTests: XCTestCase {
    func testParsesNumberedLinesAndCompletionMarkers() {
        let notes = """
        前言不是命令
        1、已完成：左右分栏
        2、增加朗读
        3. 优化咬字
        """
        let parsed = NumberedNoteParser.parse(notes)
        XCTAssertEqual(parsed.map(\.number), [1, 2, 3])
        XCTAssertTrue(parsed[0].isCompleted)
        XCTAssertFalse(parsed[1].isCompleted)
        XCTAssertEqual(parsed[1].title, "增加朗读")
    }
}
```

标题提取：去掉前导 `N、` 或 `N.` 以及可选的 `已完成：` / `已修复：` / `已实现：` 前缀。

`OptimizationQueueStoreTests.swift`：

```swift
import XCTest
@testable import AIBookEvolution

final class OptimizationQueueStoreTests: XCTestCase {
    func testMigrateCreatesUserItemsOnlyWhenJSONMissing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = OptimizationQueueStore(
            fileURL: directory.appendingPathComponent("optimization-queue.json")
        )
        let notes = "1、已完成：分栏\n2、增加朗读\n"
        let first = try store.migrateFromReadmeNotesIfNeeded(notes)
        XCTAssertEqual(first.items.count, 2)
        XCTAssertEqual(first.items[0].source, .user)
        XCTAssertEqual(first.items[0].status, .completed)
        XCTAssertEqual(first.items[1].status, .pending)

        var mutated = first
        mutated.items[1].title = "已被用户改过"
        try store.save(mutated)

        let second = try store.migrateFromReadmeNotesIfNeeded("1、全新笔记不应覆盖")
        XCTAssertEqual(second.items[1].title, "已被用户改过")
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter NumberedNoteParserTests --filter OptimizationQueueStoreTests -v`

Expected: FAIL，类型不存在。

- [ ] **Step 3: 实现 parser 与 store**

`NumberedNoteParser.swift`：把 `EvolutionPlanner.parseCommands` 的编号与完成判定原样搬过来（`已完成` / `已修复` / `已实现` / `done` / `（已经完成）`），额外提供 `title`：去掉 `^\d+[、.]\s*` 以及开头的 `已完成：` `已修复：` `已实现：`。

`OptimizationQueueStore.swift`：

```swift
public final class OptimizationQueueStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("AIBook", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("optimization-queue.json")
    }

    public func load() throws -> OptimizationQueue {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .empty
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OptimizationQueue.self, from: data)
    }

    public func save(_ queue: OptimizationQueue) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(queue)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    public func migrateFromReadmeNotesIfNeeded(_ notes: String) throws -> OptimizationQueue {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return try load()
        }
        let parsed = NumberedNoteParser.parse(notes)
        guard !parsed.isEmpty else {
            let empty = OptimizationQueue.empty
            try save(empty)
            return empty
        }
        let now = Date()
        var queue = OptimizationQueue.empty
        queue.items = parsed.map { command in
            OptimizationItem(
                id: UUID(),
                number: command.number,
                title: command.title,
                rationale: "",
                category: .featureGap,
                priority: .medium,
                risk: .low,
                suggestedFiles: [],
                source: .user,
                status: command.isCompleted ? .completed : .pending,
                pinnedAt: nil,
                createdAt: now,
                updatedAt: now,
                completionSummary: command.isCompleted ? command.title : nil
            )
        }
        queue.updatedAt = now
        try save(queue)
        return queue
    }
}
```

`OptimizationItem` 初始化参数顺序按 Task 1 的 struct 声明对齐（实现时用成员逐个赋值，避免顺序写错）。

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --filter AIBookEvolutionTests -v`

Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Sources/AIBookEvolution Tests/AIBookEvolutionTests
git commit -m "$(cat <<'EOF'
feat: persist optimization queue and migrate readme notes once

Keep JSON as the source of truth so opening a book cannot wipe the queue.
EOF
)"
```

---

### Task 3: ViewModel 进化改为消费队列

**Files:**
- Modify: `Sources/AIBook/Reading/ReadingViewModel.swift`
- Modify: `Sources/AIBook/Evolution/SelfEvolution.swift`
- Modify: `Sources/AIBook/Evolution/EvolutionPlanner.swift`
- Modify: `Sources/AIBook/Evolution/EvolutionAssistant.swift`（systemPrompt 仍说编号命令的句子先改成「优化队列条目」）

**Interfaces:**
- Consumes: `OptimizationQueueStore.defaultFileURL`、`nextPending()`、`markRunning` / `markCompleted` / `revertRunningToPending`
- Produces:
  - `ReadingViewModel.optimizationQueue: OptimizationQueue`
  - `ReadingViewModel.persistOptimizationQueue()`
  - `startEvolution()` 从 `optimizationQueue.nextPending()` 取任务
  - `applyEvolutionQueueUpdate(reply:item:)` 写 Store，不改 `fileContent`
  - `SelfEvolution.statusLabel(from queue: OptimizationQueue) -> String?`

- [ ] **Step 1: 在 ViewModel 顶部增加队列状态**

在 `import Foundation` 旁加 `import AIBookEvolution`。

增加：

```swift
@Published var optimizationQueue = OptimizationQueue.empty
private let optimizationQueueStore = OptimizationQueueStore(fileURL: OptimizationQueueStore.defaultFileURL)
```

`init()` 在 `loadReadmeNotes()` 之后：

```swift
loadOptimizationQueue()
```

```swift
private func loadOptimizationQueue() {
    do {
        optimizationQueue = try optimizationQueueStore.migrateFromReadmeNotesIfNeeded(
            readmeNotesStore.loadInitialContent()
        )
    } catch {
        errorMessage = "无法加载优化队列：\(error.localizedDescription)"
        optimizationQueue = .empty
    }
}

func persistOptimizationQueue() {
    do {
        try optimizationQueueStore.save(optimizationQueue)
    } catch {
        errorMessage = "无法保存优化队列：\(error.localizedDescription)"
    }
}
```

- [ ] **Step 2: 改 `evolutionCommands` / `evolutionStatusLabel` / `startEvolution`**

删除对 `EvolutionPlanner.parseCommands(from: fileContent)` 的运行时依赖。

```swift
var evolutionStatusLabel: String? {
    SelfEvolution.statusLabel(from: optimizationQueue)
}

var evolutionItems: [OptimizationItem] {
    optimizationQueue.items.sorted { $0.number < $1.number }
}
```

暂时保留 `evolutionCommands` 会破坏编译；**删掉该计算属性**，后续 Task 6 改 UI 使用 `evolutionItems`。若本 Task 尚未改 UI，先让 `evolutionCommands` 从队列映射一个兼容结构，避免 App 编不过：

```swift
var evolutionCommands: [EvolutionPlanner.Command] {
    optimizationQueue.items
        .sorted { $0.number < $1.number }
        .map { item in
            EvolutionPlanner.Command(
                number: item.number,
                text: "\(item.number)、\(item.title)",
                isCompleted: item.status == .completed
            )
        }
}
```

`EvolutionPlanner.Command` 的 `text` / `isCompleted` 若成员不可从外部构造，改为 `public` 或增加 `init`。

重写 `startEvolution()`：

```swift
func startEvolution() {
    selectRightPageTab(.aiEvolution)
    ensureEvolutionWelcome()

    if let running = optimizationQueue.items.first(where: { $0.status == .running }) {
        _ = optimizationQueue.revertRunningToPending(id: running.id)
        persistOptimizationQueue()
    }

    guard let pending = optimizationQueue.nextPending() else {
        errorMessage = "请先点「分析优化」，或在队列中手写一条。"
        AutoEvolutionCoordinator.clearChain()
        return
    }

    if let configError = AppGuard.explanationSourceErrorMessage(for: AppSettings.shared) {
        errorMessage = configError
        return
    }
    guard SelfEvolution.sourceProjectReady else {
        errorMessage = "未找到 ai-book 源码目录（需含 Package.swift 与 Sources/AIBook）。请确认 \(SelfEvolution.sourceProjectPath()) 存在。"
        return
    }

    let prompt = EvolutionPlanner.buildEvolutionPrompt(
        queue: optimizationQueue,
        pending: pending,
        projectPath: SelfEvolution.sourceProjectPath()
    )
    guard guardEvolutionTokenLimit(for: prompt, action: "执行进化") else { return }

    guard optimizationQueue.markRunning(id: pending.id) else { return }
    persistOptimizationQueue()
    AutoEvolutionCoordinator.markChainActive()

    sendMessage(
        prompt,
        displayText: "自我进化 · 第 \(pending.number) 条",
        isEvolution: true,
        evolutionCommandNumber: pending.number,
        triggerEvolutionRebuild: true
    )
}
```

本 Task 先给 `EvolutionPlanner.buildEvolutionPrompt(queue:pending:projectPath:)` 一个**过渡实现**：内部仍用旧的 8 条纪律，但「左页全部命令」改为队列摘要，「当前待进化」用 `pending.title` + `pending.rationale`。完整 Prompt 在 Task 5 替换。签名：

```swift
static func buildEvolutionPrompt(
    queue: OptimizationQueue,
    pending: OptimizationItem,
    projectPath: String
) -> String
```

删除旧的 `allCommands:pending: Command` 重载。`buildEvolutionChatPrompt` 同样改为读 `optimizationQueue`。

- [ ] **Step 3: 完成写回与空队列不再重启**

把 `applyEvolutionReadmeUpdate` 换成：

```swift
private func applyEvolutionQueueUpdate(reply: String, commandNumber: Int?) {
    guard let number = commandNumber,
          let item = optimizationQueue.items.first(where: { $0.number == number })
    else { return }

    let summary = EvolutionPlanner.parseCompletionSummary(from: reply, number: number)
        ?? "第 \(number) 条自我进化已执行。"
    if optimizationQueue.items.first(where: { $0.id == item.id })?.status == .running {
        _ = optimizationQueue.markCompleted(id: item.id, summary: summary)
    } else {
        if let index = optimizationQueue.items.firstIndex(where: { $0.id == item.id }) {
            optimizationQueue.items[index].status = .completed
            optimizationQueue.items[index].completionSummary = summary
        }
    }
    persistOptimizationQueue()
}
```

本 Task 的 `parseCompletionSummary` 先实现为：在回复中找 `"\(number)、已完成"` 行，取冒号后文本；找不到则返回 `nil`。Task 5 再加 `<<<EVOLUTION_DONE>>>` 块。

`sendMessage` 成功分支里：把 `applyEvolutionReadmeUpdate` 换成 `applyEvolutionQueueUpdate`。`stillPending` 改为 `optimizationQueue.nextPending() != nil`。

删除 `restartWhenEvolutionQueueEmpty()` 的调用路径：`startEvolution` 在无 pending 时只提示，不打包。`sendMessage` 在全部完成后仍 `rebuildAndRelaunch` 一次（最后一条刚完成需要安装），然后依赖 Task 4 的 `clearChain`。

`stopCurrentRun()`：若 `executingEvolutionCommandNumber` 非空，对该 number 对应条目 `revertRunningToPending` 并 `persistOptimizationQueue()`。

`scheduleAutoEvolutionIfNeeded` 里 `pendingCount` 改为 `optimizationQueue.items.filter { $0.status == .pending }.count`。门闩留到 Task 4。

- [ ] **Step 4: `SelfEvolution.statusLabel`**

增加 `statusLabel(from queue: OptimizationQueue) -> String?`：无条目返回 `nil`；pending 为 0 返回 `优化队列已全部完成`（**不要**「将自动重启」）；否则 `待优化 \(pending) 条 · 下一条 #\(number) \(title)`，自动升级中且 `AutoEvolutionCoordinator.isChainActive` 时前缀 `自动升级中 ·`。

保留旧 `status(from content:)` 暂不删除也可以，但 App 侧停止调用。

- [ ] **Step 5: 编译**

Run: `swift build`

Expected: 成功。`swift test` 仍 PASS。

手动验证（实现者本机）：启动 App，打开任意 `.txt`，右页 AI 进化队列仍显示迁移条目，点进化应对队列项而不是书籍正文。

- [ ] **Step 6: Commit**

```bash
git add Sources/AIBook Package.swift
git commit -m "$(cat <<'EOF'
feat: drive evolution from the optimization queue

Stop parsing the open book as numbered commands so reading and upgrades no longer collide.
EOF
)"
```

---

### Task 4: 自动升级链门闩

**Files:**
- Modify: `Sources/AIBook/Evolution/AutoEvolutionCoordinator.swift`
- Modify: `Sources/AIBook/Reading/ReadingViewModel.swift`（`scheduleAutoEvolutionIfNeeded`、构建失败清链）
- Modify: `Sources/AIBook/UI/SettingsView.swift`
- Create: `Tests/AIBookEvolutionTests/AutoEvolutionPolicyTests.swift`（纯策略函数，避免测 AppKit）

**Interfaces:**
- Consumes: Task 3 的队列 pending 计数、`startEvolution` 已 `markChainActive`
- Produces:
  - `AutoEvolutionCoordinator.shouldAutoStart(autoEvolutionEnabled:isChainActive:pendingCount:) -> Bool`
  - 设置文案改为「仅在点过进化之后，重启后继续下一条」

- [ ] **Step 1: 写失败测试**

把策略从 coordinator 抽成库内函数，避免测试依赖 App 的 UserDefaults 文件：

在 `Sources/AIBookEvolution/AutoEvolutionPolicy.swift`：

```swift
public enum AutoEvolutionPolicy {
    public static func shouldAutoStart(
        autoEvolutionEnabled: Bool,
        isChainActive: Bool,
        pendingCount: Int
    ) -> Bool {
        autoEvolutionEnabled && isChainActive && pendingCount > 0
    }
}
```

测试：

```swift
func testColdStartWithPendingDoesNotAutoStart() {
    XCTAssertFalse(
        AutoEvolutionPolicy.shouldAutoStart(
            autoEvolutionEnabled: true,
            isChainActive: false,
            pendingCount: 3
        )
    )
}

func testChainContinuesWhenEnabled() {
    XCTAssertTrue(
        AutoEvolutionPolicy.shouldAutoStart(
            autoEvolutionEnabled: true,
            isChainActive: true,
            pendingCount: 1
        )
    )
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter AutoEvolutionPolicyTests -v`

Expected: FAIL until the type exists.

- [ ] **Step 3: 实现并接到 App**

`AutoEvolutionCoordinator.shouldAutoStart` 改为调用 `AutoEvolutionPolicy`，增加参数 `isChainActive`。删除旧的两参数方法。

`scheduleAutoEvolutionIfNeeded`：

```swift
guard AutoEvolutionPolicy.shouldAutoStart(
    autoEvolutionEnabled: settings.autoEvolutionEnabled,
    isChainActive: AutoEvolutionCoordinator.isChainActive,
    pendingCount: pending
) else {
    if pending == 0 {
        AutoEvolutionCoordinator.clearChain()
    }
    return
}
```

确认 `startEvolution` 在真正 `sendMessage` 之前才 `markChainActive`（Task 3 已做）。`analyzeOptimizations` 尚未存在，不得 mark。

`handleEvolutionRebuild` 失败分支已 `clearChain`（`AppRelauncher.rebuildAndRelaunch` 失败时）。成功且 `nextPending() == nil` 时，在 relaunch 前 `clearChain()`——注意 `rebuildAndRelaunch` 成功路径里又 `markChainActive()`。要改 `AppRelauncher.rebuildAndRelaunch`：增加参数 `continueChain: Bool`；`false` 时成功也 `clearChain()`。ViewModel 在调用处：

```swift
let continueChain = AppSettings.shared.autoEvolutionEnabled
    && optimizationQueue.nextPending() != nil
await AppRelauncher.rebuildAndRelaunch(projectPath: projectPath)
```

更好：在 `handleEvolutionRebuild` 里若 `!continueChain`，成功后不要依赖 relaunch 里的 mark；改 `AppRelauncher`：

```swift
static func rebuildAndRelaunch(
    projectPath: String,
    relaunchDelay: TimeInterval = 1.5,
    continueChain: Bool
) async -> RebuildResult
```

`continueChain == false` 时：`clearChain()` 再 relaunch。`true` 时保持现有 `markChainActive()`。

设置 Toggle 文案：

```
自动升级（点过「进化」后，重启继续下一条）
```

说明改为：开启后，只有已经点过「进化」并留下待办时，重启才会继续；不会因为队列里有分析条目就在冷启动时改码。

- [ ] **Step 4: 运行测试与编译**

Run: `swift test --filter AutoEvolutionPolicyTests -v && swift build`

Expected: PASS + 编译成功。

- [ ] **Step 5: Commit**

```bash
git add Sources/AIBookEvolution Sources/AIBook Tests/AIBookEvolutionTests
git commit -m "$(cat <<'EOF'
fix: auto-upgrade only continues an active evolution chain

Cold launch with a full queue must not rewrite source until the user clicks Evolve.
EOF
)"
```

---

### Task 5: 进化 Prompt 与完成摘要解析

**Files:**
- Modify: `Sources/AIBook/Evolution/EvolutionPlanner.swift`
- Create: `Tests/AIBookEvolutionTests/EvolutionCompletionParserTests.swift`
- Move parser into library: `Sources/AIBookEvolution/EvolutionCompletionParser.swift`

**Interfaces:**
- Consumes: `OptimizationQueue`、`OptimizationItem`
- Produces:
  - `EvolutionPlanner.buildEvolutionPrompt(queue:pending:projectPath:) -> String`
  - `EvolutionCompletionParser.summary(from:number:) -> String?`

- [ ] **Step 1: 写失败测试**

```swift
func testParsesEvolutionDoneBlock() {
    let reply = """
    改完了。
    <<<EVOLUTION_DONE>>>
    {"number": 12, "summary": "读书助手增加讲解对话区"}
    <<<END>>>
    """
    XCTAssertEqual(
        EvolutionCompletionParser.summary(from: reply, number: 12),
        "读书助手增加讲解对话区"
    )
}

func testFallsBackToNumberedCompletedLine() {
    let reply = "12、已完成：补上对话区"
    XCTAssertEqual(
        EvolutionCompletionParser.summary(from: reply, number: 12),
        "补上对话区"
    )
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter EvolutionCompletionParserTests -v`

Expected: FAIL。

- [ ] **Step 3: 实现 parser 与 Prompt**

Parser：优先用正则 `<<<EVOLUTION_DONE>>>\s*(\{[\s\S]*?\})\s*<<<END>>>`，JSON `number` 必须匹配参数，取 `summary` 字符串。否则找以 `"\(number)、"` 开头且含 `已完成` 的行，取第一个中文冒号或 `:` 之后的文本。

`buildEvolutionPrompt` 正文必须包含：

- `【AIBook 产品定义】` 使用 `SelfEvolution.productDefinition`（Planner 仍在 App 模块，可继续引用）
- `【优化队列摘要】` 每行 `○/#n pending标题` 或 `✓/#n completed标题`
- `【当前待进化】` number、title、rationale、category.rawValue、priority、risk、suggestedFiles
- `【源码目录】`
- 任务纪律 1–8（与现网相同），第 6 条改为输出：

```
<<<EVOLUTION_DONE>>>
{"number": <pending.number>, "summary": "一句话"}
<<<END>>>
```

并写明：不要 `git commit` / `git push`；不要修改 `optimization-queue.json`（由应用写入）。

`ViewModel.applyEvolutionQueueUpdate` 改用 `EvolutionCompletionParser.summary`。

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --filter EvolutionCompletionParserTests -v && swift build`

Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Sources/AIBookEvolution Sources/AIBook Tests/AIBookEvolutionTests
git commit -m "$(cat <<'EOF'
feat: build evolution prompts from queue items

Give the agent structured work items and a machine-readable completion block.
EOF
)"
```

---

### Task 6: 队列 UI 改为条目列表（只读展示 + 空态）

**Files:**
- Modify: `Sources/AIBook/Evolution/EvolutionExecutionViews.swift`
- Modify: `Sources/AIBook/Reading/ExplanationChatView.swift`
- Modify: `Sources/AIBook/Reading/ContentView.swift`（Tab 帮助：不要再说「按左页编号命令」）

**Interfaces:**
- Consumes: `viewModel.evolutionItems` / `optimizationQueue`
- Produces: `EvolutionCommandQueuePanel(items: [OptimizationItem], ...)` 竖向列表；空态「点「分析优化」，让 AI 找出可改进处」

- [ ] **Step 1: 改面板数据源**

`EvolutionUtilityTabsPanel` 把 `commands: [EvolutionPlanner.Command]` 换成 `items: [OptimizationItem]`。`ExplanationChatView` 传入 `viewModel.evolutionItems`。

徽章：`completedCount/total` 用 `status == .completed`。

- [ ] **Step 2: 重写 `EvolutionCommandQueuePanel`**

每条一行（不要再横滑 chip）：

```
[#12] 标题…    [AI|手写]  [待办|执行中|完成|跳过]  类别
下一条高亮皮革色；running 显示 Progress
```

空态：

```
点「分析优化」，让 AI 找出可改进处
也可稍后在队列中手写一条。
```

底部仍显示 `projectPath`。本 Task **不要**加跳过/删除按钮（Task 10）。

- [ ] **Step 3: 顶栏帮助**

`ContentView` 中 `.help("切换到 AI 进化：按左页编号命令升级 ai-book")` 改为 `切换到 AI 进化：分析优化点并自动升级`。

- [ ] **Step 4: 编译**

Run: `swift build`

Expected: 成功。手动：队列展示迁移项；打开书籍后列表不变。

- [ ] **Step 5: Commit**

```bash
git add Sources/AIBook
git commit -m "$(cat <<'EOF'
feat: show the optimization queue independently of the left page

Users can read a book while the upgrade list stays visible.
EOF
)"
```

---

### Task 7: EvolutionAnalyzer Prompt 与输出解析

**Files:**
- Create: `Sources/AIBookEvolution/EvolutionAnalyzer.swift`
- Create: `Tests/AIBookEvolutionTests/EvolutionAnalyzerTests.swift`

**Interfaces:**
- Consumes: `OptimizationQueue`
- Produces:
  - `EvolutionAnalyzer.capabilityMap: String`
  - `EvolutionAnalyzer.analysisSystemPrompt: String`
  - `EvolutionAnalyzer.buildAnalysisPrompt(queue:projectPath:) -> String`
  - `EvolutionAnalyzer.parseItems(from:) -> [OptimizationDraft]`

- [ ] **Step 1: 写失败测试**

```swift
final class EvolutionAnalyzerTests: XCTestCase {
    func testParsesFencedJSON() {
        let reply = """
        说明若干。
        <<<OPTIMIZATION_QUEUE>>>
        [
          {
            "title": "读书助手展示讲解对话与流式输出",
            "rationale": "讲解只朗读不显示。",
            "category": "ux",
            "priority": "high",
            "risk": "medium",
            "suggestedFiles": ["Sources/AIBook/Reading/ExplanationChatView.swift"]
          }
        ]
        <<<END>>>
        """
        let items = EvolutionAnalyzer.parseItems(from: reply)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].category, .ux)
        XCTAssertEqual(items[0].priority, .high)
        XCTAssertEqual(items[0].suggestedFiles.count, 1)
    }

    func testFallsBackToNumberedTitles() {
        let reply = """
        1、补上讲解对话区
        2、翻译入口提前
        """
        let items = EvolutionAnalyzer.parseItems(from: reply)
        XCTAssertEqual(items.map(\.title), ["补上讲解对话区", "翻译入口提前"])
        XCTAssertEqual(items[0].category, .featureGap)
        XCTAssertEqual(items[0].priority, .medium)
    }

    func testInvalidJSONWithoutNumbersReturnsEmpty() {
        XCTAssertTrue(EvolutionAnalyzer.parseItems(from: "随便聊聊").isEmpty)
    }

    func testPromptIncludesQueueTitlesAndForbidsEdits() {
        var queue = OptimizationQueue.empty
        queue.items = [
            OptimizationItem(
                id: UUID(), number: 1, title: "已有项", rationale: "", category: .ux,
                priority: .medium, risk: .low, suggestedFiles: [], source: .user,
                status: .completed, pinnedAt: nil, createdAt: Date(), updatedAt: Date(),
                completionSummary: nil
            )
        ]
        let prompt = EvolutionAnalyzer.buildAnalysisPrompt(queue: queue, projectPath: "/tmp/ai-book")
        XCTAssertTrue(prompt.contains("已有项"))
        XCTAssertTrue(prompt.contains("禁止修改任何文件"))
        XCTAssertTrue(prompt.contains("<<<OPTIMIZATION_QUEUE>>>"))
        XCTAssertTrue(prompt.contains(EvolutionAnalyzer.capabilityMap))
    }
}
```

未知 `category`/`priority`/`risk` 时分别回落到 `featureGap` / `medium` / `low`。缺 `title` 的 JSON 对象丢弃。

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter EvolutionAnalyzerTests -v`

Expected: FAIL。

- [ ] **Step 3: 实现 Analyzer**

`capabilityMap` 写成约 25 行静态字符串，覆盖：左页阅读、读书助手讲解、翻译、名著补充、语音、AI 进化、双后端、设置。并写一句：「用户可感知缺口（讲解看不见、入口过深）优先于重构、注释、重命名。」

`buildAnalysisPrompt` 拼接：产品定义（Analyzer 内写与 `AIBookProduct.positioning` 等价的固定中文，避免库依赖 App）、队列待办/已完成标题列表、capabilityMap、源码目录、只读工具说明、禁止 apply diff、输出围栏格式、最多 8 条、优先 UX。

`parseItems`：先抽围栏 JSON；失败再按行 `NumberedNoteParser` 风格取未完成标题作为 draft（rationale 空）。

在同一文件增加 `analysisSystemPrompt`（Task 9 分析通道的 system 角色）：

```swift
public static let analysisSystemPrompt = """
你是 AIBook 的优化分析器。只诊断，不改文件、不 apply diff、不运行会改动工作区的命令。
最后必须输出 <<<OPTIMIZATION_QUEUE>>> JSON 数组 <<<END>>>。
"""
```

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --filter EvolutionAnalyzerTests -v`

Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Sources/AIBookEvolution Tests/AIBookEvolutionTests
git commit -m "$(cat <<'EOF'
feat: parse AI optimization analysis into queue drafts

Keep analysis output structured so enqueueing does not depend on left-page notes.
EOF
)"
```

---

### Task 8: 分析期只读工具

**Files:**
- Create: `Sources/AIBookEvolution/EvolutionToolPolicy.swift`
- Create: `Tests/AIBookEvolutionTests/EvolutionToolPolicyTests.swift`
- Modify: `Sources/AIBook/Evolution/EvolutionLocalTools.swift`
- Modify: `Sources/AIBook/LLM/LLMEvolutionAgent.swift`
- Modify: `Sources/AIBook/Reading/ReadingViewModel.swift`（`fetchLLMEvolutionReply` 传参）

**Interfaces:**
- Consumes: 无
- Produces:
  - `EvolutionToolPolicy.isMutating(_ name: String) -> Bool`
  - `EvolutionLocalTools.openAIToolDefinitions(allowMutations: Bool)`
  - `EvolutionLocalTools.execute(..., allowMutations: Bool = true)`
  - `LLMEvolutionAgent.run(..., allowMutations: Bool = true, maxIterations: Int? = nil)`

- [ ] **Step 1: 写失败测试**

```swift
final class EvolutionToolPolicyTests: XCTestCase {
    func testReadToolsAreNotMutating() {
        for name in ["read", "grep", "glob", "read_file", "glob_file_search"] {
            XCTAssertFalse(EvolutionToolPolicy.isMutating(name))
        }
    }

    func testEditWriteShellAreMutating() {
        for name in ["edit", "write", "shell", "strreplace", "write_file", "run_terminal_cmd"] {
            XCTAssertTrue(EvolutionToolPolicy.isMutating(name))
        }
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter EvolutionToolPolicyTests -v`

Expected: FAIL。

- [ ] **Step 3: 实现 policy 并接到 tools/agent**

```swift
public enum EvolutionToolPolicy {
    public static func isMutating(_ name: String) -> Bool {
        switch name.lowercased() {
        case "read", "read_file", "grep", "glob", "glob_file_search":
            return false
        default:
            return true
        }
    }
}
```

`EvolutionLocalTools.ToolError` 增加 `mutationBlocked(String)`，文案：`分析模式禁止 \(name)，请只使用 read / grep / glob。`

`execute` 在 switch 之前：

```swift
if !allowMutations, EvolutionToolPolicy.isMutating(name) {
    return .failure(.mutationBlocked(name))
}
```

`openAIToolDefinitions` 改为函数；`allowMutations == false` 时只返回 read/grep/glob 三项。保留 `static var openAIToolDefinitions` 为 `openAIToolDefinitions(allowMutations: true)` 以免漏改。

`LLMEvolutionAgent.run` 增加参数，内部：

```swift
let iterationLimit = maxIterations ?? 24
let tools = EvolutionLocalTools.openAIToolDefinitions(allowMutations: allowMutations)
```

循环条件与最终超限文案用 `iterationLimit`。`executeToolCalls` 增加 `allowMutations` 并传入 `EvolutionLocalTools.execute`。

`fetchLLMEvolutionReply` 增加 `allowMutations: Bool = true, maxIterations: Int? = nil` 并原样传给 `run`。现有进化调用保持默认值。

- [ ] **Step 4: 运行测试并编译**

Run: `swift test --filter EvolutionToolPolicyTests -v && swift build`

Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add Sources/AIBookEvolution Sources/AIBook Tests/AIBookEvolutionTests
git commit -m "$(cat <<'EOF'
feat: block mutating tools during optimization analysis

Analysis can inspect the tree but cannot edit files or run shell.
EOF
)"
```

---

### Task 9: 「分析优化」编排与按钮

**Files:**
- Modify: `Sources/AIBook/Reading/ReadingViewModel.swift`
- Modify: `Sources/AIBook/Evolution/EvolutionExecutionViews.swift`
- Modify: `Sources/AIBook/Reading/ExplanationChatView.swift`
- Modify: `Sources/AIBook/Evolution/EvolutionAssistant.swift`（欢迎语）

**Interfaces:**
- Consumes: `EvolutionAnalyzer.buildAnalysisPrompt` / `parseItems`、`queue.merge`、`LLMEvolutionAgent(allowMutations: false, maxIterations: 8)`
- Produces:
  - `ReadingViewModel.analyzeOptimizations()`
  - `ReadingViewModel.isAnalyzing`（`isRunning && evolutionRunKind == .analysis`）
  - 面板按钮「分析优化」；空态按钮调用同一方法
  - 成功后切到队列 Tab、对话区摘要、**不** `AppRelauncher`、**不** `markChainActive`

- [ ] **Step 1: ViewModel 增加运行种类**

```swift
enum EvolutionRunKind {
    case none
    case analysis
    case evolution
}
@Published private(set) var evolutionRunKind: EvolutionRunKind = .none
```

`beginRun` / `clearEvolutionExecutionState` / `stopCurrentRun` 结束时设回 `.none`。`stopCurrentRun` 对 analysis **不要** revert 队列 running（分析不 markRunning）。

扩展 `sendMessage`（或新建 `sendEvolutionRun`）参数：

```swift
evolutionRunKind: EvolutionRunKind = .none
```

`isEvolution` 仍为 `evolutionRunKind != .none`（分析也走进化对话上下文与轨迹）。仅 `evolutionRunKind == .evolution` 时 `triggerEvolutionRebuild == true` 且 `markChainActive`。

`fetchAssistantReply` 增加 `allowMutations: Bool`：analysis 为 `false`。Cursor 通道分析时 `systemInstruction` 使用 `EvolutionAnalyzer.buildAnalysisPrompt` 已含「禁止修改文件」；仍用 `EvolutionAssistant.systemPrompt` 会鼓励改码——分析时改用已有的 `EvolutionAnalyzer.analysisSystemPrompt`（Task 7 已定义）。

- [ ] **Step 2: 实现 `analyzeOptimizations()`**

```swift
func analyzeOptimizations() {
    selectRightPageTab(.aiEvolution)
    ensureEvolutionWelcome()
    guard !isRunning, !isEvolutionRebuilding else { return }
    if let configError = AppGuard.explanationSourceErrorMessage(for: AppSettings.shared) {
        errorMessage = configError
        return
    }
    guard SelfEvolution.sourceProjectReady else {
        errorMessage = "未找到 ai-book 源码目录（需含 Package.swift 与 Sources/AIBook）。请确认 \(SelfEvolution.sourceProjectPath()) 存在。"
        return
    }
    let prompt = EvolutionAnalyzer.buildAnalysisPrompt(
        queue: optimizationQueue,
        projectPath: SelfEvolution.sourceProjectPath()
    )
    guard guardEvolutionTokenLimit(for: prompt, action: "分析优化") else { return }
    evolutionRunKind = .analysis
    sendMessage(
        prompt,
        displayText: "分析优化",
        isEvolution: true,
        evolutionCommandNumber: nil,
        triggerEvolutionRebuild: false,
        evolutionRunKind: .analysis
    )
}
```

在 `sendMessage` 完成分支，当 `evolutionRunKind == .analysis`：

1. 若能定位 git 仓库，运行 `git -C projectPath status --porcelain`；stdout 非空则 **不 merge**，助手消息：「分析过程修改了源码，已放弃入队。请用 git 恢复后重试。」
2. 否则 `let drafts = EvolutionAnalyzer.parseItems(from: resolvedReply)`；`let report = optimizationQueue.merge(drafts: drafts)`；`persistOptimizationQueue()`。
3. 追加助手消息：`drafts.isEmpty ? "未发现新的优化项。" : report.summaryChinese`。
4. `UserDefaults.standard.set(EvolutionUtilityTab.queue.rawValue, forKey: "evolutionUtilityTab")`（与面板 `@AppStorage("evolutionUtilityTab")` 同一 key，rawValue 已是 `"队列"`）。
5. 绝不调用 `handleEvolutionRebuild` / `markChainActive`。

`fetchLLMEvolutionReply` 在 analysis 时：`allowMutations: false, maxIterations: 8`。

把 `evolutionRunKind` 传入 `sendMessage` 闭包，避免结束时已被清空——在 `sendMessage` 开头用局部常量 `let runKind = evolutionRunKind`。

- [ ] **Step 3: UI 按钮**

`evolutionActionRow`：

```swift
BookPageActionButton(
    title: "分析优化",
    icon: "magnifyingglass",
    isProminent: false,
    isDisabled: isRunning || isEvolutionRebuilding || !canRunEvolution
) { onAnalyze() }

BookPageActionButton(
    title: "进化",
    ...
    isDisabled: isRunning || isEvolutionRebuilding || !canRunEvolution || !hasPending
)
```

`EvolutionUtilityTabsPanel` 增加 `hasPending: Bool`、`onAnalyze: () -> Void`。`ExplanationChatView` 接 `viewModel.analyzeOptimizations` 与 `viewModel.optimizationQueue.nextPending() != nil`。

运行中若 `isAnalyzing`，状态文字用「分析中」而不是「第 N 条」。空态按钮 `onAnalyze`。

欢迎语改为：先点「分析优化」入队，再点「进化」或 ⌘E 升级；⌘E 不触发分析。

- [ ] **Step 4: 编译与手工验收**

Run: `swift build && swift test`

Expected: 编译成功，库测试 PASS。

手工（实现者）：

1. 不写左页命令，点「分析优化」→ 队列出现带理由条目。
2. 分析期间 `git status` 在源码目录应干净（或入队被拒绝）。
3. 分析结束后应用未重启。
4. 未配置后端 / Token 超限 / 无源码路径时有中文错误。

- [ ] **Step 5: Commit**

```bash
git add Sources/AIBook Sources/AIBookEvolution
git commit -m "$(cat <<'EOF'
feat: add Analyze Optimizations to fill the upgrade queue

Users can discover work items without editing source or relaunching.
EOF
)"
```

---

### Task 10: 队列跳过 / 删除 / 置顶 / 手写 / 改标题

**Files:**
- Modify: `Sources/AIBook/Reading/ReadingViewModel.swift`
- Modify: `Sources/AIBook/Evolution/EvolutionExecutionViews.swift`

**Interfaces:**
- Consumes: Task 1 已有 `skip` / `remove` / `pin` / `addUserItem` / `updateTitle` / `restore`
- Produces: ViewModel 包装方法并 `persistOptimizationQueue()`；队列行操作菜单

- [ ] **Step 1: ViewModel API**

```swift
func skipOptimization(id: UUID) {
    guard !isRunning else { return }
    _ = optimizationQueue.skip(id: id)
    persistOptimizationQueue()
}
func restoreOptimization(id: UUID) { ... restore ... }
func deleteOptimization(id: UUID) { ... remove ... }
func pinOptimization(id: UUID) { ... pin ... }
func addUserOptimization(title: String) {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    _ = optimizationQueue.addUserItem(title: trimmed)
    persistOptimizationQueue()
}
func renameOptimization(id: UUID, title: String) { ... updateTitle ... }
```

运行中禁止改正在 `running` 的条目（除 stop 已处理的 revert）。

- [ ] **Step 2: UI**

每条 pending：`contextMenu` 或行尾「⋯」：置顶、跳过、删除、编辑标题（`Alert` / `prompt` 用 `NSAlert` 或内联 `TextField`）。skipped：恢复、删除。completed：只读。

列表底部：

```swift
TextField("手写一条优化…", text: $draftTitle)
Button("添加") { onAdd(draftTitle); draftTitle = "" }
```

用 `@State private var draftTitle = ""` 放在 `EvolutionCommandQueuePanel`。面板增加对应闭包。

- [ ] **Step 3: 编译**

Run: `swift build`

Expected: 成功。手工：手写一条 → 点进化走该条；跳过的项分析去重后不再入队（标题相同）。

- [ ] **Step 4: Commit**

```bash
git add Sources/AIBook
git commit -m "$(cat <<'EOF'
feat: let users edit the optimization queue

Skip, pin, delete, and handwritten items keep the human in control of upgrades.
EOF
)"
```

---

### Task 11: 文案、设置与设计文档同步

**Files:**
- Modify: `Sources/AIBook/Evolution/EvolutionAssistant.swift`
- Modify: `Sources/AIBook/Core/AIBookProduct.swift`
- Modify: `Sources/AIBook/UI/SettingsView.swift`（若 Task 4 未改完）
- Modify: `整体功能文档设计.md`（§4.6、§6.1、§11.4）
- Modify: `整体UI文档设计.md`（§3.9、§4.4）
- Modify: `aibook进化设计.md` 仅当实现与设计有意偏移时回写一句

**Interfaces:**
- Consumes: 已落地行为
- Produces: 文档与 UI 文案一致

- [ ] **Step 1: 产品文案**

`AIBookProduct.aboutLines` 最后一行改为：`支持大模型 API 与 Cursor 本地对话，可由 AI 分析优化队列并一键升级。`

`EvolutionAssistant.welcomeMessage` 必须出现：「分析优化」「优化队列」「进化 / ⌘E」「分析不改码」。

- [ ] **Step 2: 功能文档 §4.6**

替换「左页编号命令驱动」为两段流程（分析入队 / 进化升级）。存储表增加 `optimization-queue.json`。工作流 11.4 改为：分析优化 → 队列确认 → 进化 → 构建重启。

- [ ] **Step 3: UI 文档**

§3.9 操作行含「分析优化」；队列为独立列表。§4.4 流程图与设计文档第 4 节一致。

- [ ] **Step 4: 全量验证**

Run: `swift test && swift build`

对照 [aibook进化设计.md](./aibook进化设计.md) §14 逐条勾验收：

1. 不写左页命令，分析能入队。
2. 分析不改源码。
3. 打开 `.txt` 后队列仍在。
4. 进化一次只完成一条并构建重启。
5. 冷启动有 pending 但不 `isChainActive` 时不自动进化。
6. 点过进化且自动升级开启时重启后续跑。
7. 跳过/删除/手写可用；再分析不重复标题。
8. 缺配置 / Token / 无源码时报中文错误。

- [ ] **Step 5: Commit**

```bash
git add Sources/AIBook 整体功能文档设计.md 整体UI文档设计.md aibook进化设计.md
git commit -m "$(cat <<'EOF'
docs: align evolution copy with analyze-then-upgrade

Keep product docs matching the independent optimization queue.
EOF
)"
```

---

## Spec coverage

| 设计章节 | 任务 |
|----------|------|
| §1 两段流程与三条硬约束 | Task 3、4、8、9 |
| §3 方案 C 独立 JSON | Task 1–2 |
| §4 用户流程 | Task 9–10 |
| §5 模块表 | 全文 File Structure |
| §6 数据模型 / 选择器 / 迁移 | Task 1–2 |
| §7 分析入口、Prompt、工具、解析、合并、成功 UI | Task 7–9 |
| §8 进化触发、Prompt、状态、自动链、空队列不空转重启 | Task 3–5、4 |
| §9 双通道 | Task 8–9（Cursor 只读靠 Prompt + git status） |
| §10 UI | Task 6、9、10 |
| §11 安全 | Task 4、8、9 |
| §14 验收 | Task 11 Step 4 |
| §15 文档 | Task 11 |

## Type checklist

- `OptimizationQueue.nextPending() -> OptimizationItem?` 在 Task 1 定义，Task 3/9/10 使用。
- `merge(drafts:maxNewItems:) -> MergeReport` Task 1 定义，Task 9 使用。
- `LLMEvolutionAgent.run(..., allowMutations:maxIterations:)` Task 8 定义，Task 9 以 `false` / `8` 调用。
- `analyzeOptimizations()` 与 `startEvolution()` 都在 `ReadingViewModel`。
- `AppStorage` key 固定为 `"evolutionUtilityTab"`，值为 `"队列"` / `"进化"`。

import XCTest
@testable import AIBookEvolution

/// 队列：去重标题、置顶优先、同时只跑一条、笔记导入。
final class OptimizationQueueTests: XCTestCase {
    /// 中文逗号句号收成 ASCII，去首尾空白，用来去重。
    func testNormalizedTitleUnifiesWhitespaceAndChinesePunctuation() {
        XCTAssertEqual(
            OptimizationItem.normalizedTitle("  读书助手，展示讲解。  "),
            "读书助手,展示讲解."
        )
    }

    /// 下一件：置顶 > 高优先级 > 编号小。
    func testNextPendingPrefersPinnedThenHighPriorityThenNumber() {
        var queue = OptimizationQueue.empty
        let lowEarly = makeItem(number: 1, priority: .low)
        let highLate = makeItem(number: 3, priority: .high)
        let medium = makeItem(number: 2, priority: .medium)
        queue.items = [lowEarly, medium, highLate]
        XCTAssertEqual(queue.nextPending()?.number, 3) // 没置顶时高优先级先于编号 1

        queue.pin(id: lowEarly.id)
        XCTAssertEqual(queue.nextPending()?.id, lowEarly.id) // 置顶压过优先级
    }

    /// 同标题跳过；单次最多入队 8 条新的。
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
        XCTAssertEqual(report.duplicatesSkipped, 1) // 「修复朗读」已在队列
        XCTAssertEqual(report.enqueued, 8) // maxNewItems=8，第 10 条截掉
        XCTAssertEqual(report.truncated, 1) // 10-1重复-8入队=1 截断
        XCTAssertEqual(queue.items.filter { $0.status == .pending }.count, 9)
        XCTAssertEqual(queue.items.map(\.number).max(), 9)
    }

    /// 同时只能 running 一条；已完成不能再 markRunning。
    func testMarkRunningRejectsSecondItemAndCompletedCannotRun() {
        var queue = OptimizationQueue.empty
        let first = makeItem(number: 1)
        let second = makeItem(number: 2)
        queue.items = [first, second]
        XCTAssertTrue(queue.markRunning(id: first.id))
        XCTAssertFalse(queue.markRunning(id: second.id)) // 已有 running 拒绝第二条
        XCTAssertTrue(queue.markCompleted(id: first.id, summary: "完成"))
        XCTAssertFalse(queue.markRunning(id: first.id)) // 完成态不能重跑
        XCTAssertTrue(queue.revertRunningToPending(id: second.id) == false)
        _ = queue.markRunning(id: second.id)
        XCTAssertTrue(queue.revertRunningToPending(id: second.id))
        XCTAssertEqual(queue.items.first { $0.id == second.id }?.status, .pending)
    }

    /// 笔记导入：完成/待办和 source=.user。
    func testImportFromNotesBuildsQueueWithCompletionStatus() {
        let notes = """
        1、已完成：左右分栏
        2、增加朗读
        """
        let queue = OptimizationQueue.importFromNotes(notes)
        XCTAssertEqual(queue.items.count, 2)
        XCTAssertEqual(queue.items[0].number, 1)
        XCTAssertEqual(queue.items[0].status, .completed)
        XCTAssertEqual(queue.items[0].source, .user)
        XCTAssertEqual(queue.items[1].number, 2)
        XCTAssertEqual(queue.items[1].status, .pending)
        XCTAssertEqual(queue.items[1].title, "增加朗读")
    }

    /// 没有编号行就空队列，不造假项。
    func testImportFromNotesReturnsEmptyForInvalidContent() {
        let queue = OptimizationQueue.importFromNotes("没有编号命令\n纯文本")
        XCTAssertTrue(queue.items.isEmpty)
    }

    /// 导入→格式化→再导入，完成数和标题不变。
    func testImportFromNotesRoundTripsWithFormatter() {
        let notes = """
        1、已完成：左右分栏
        2、增加朗读
        3、自我进化
        """
        let imported = OptimizationQueue.importFromNotes(notes)
        let formatted = NumberedNoteFormatter.format(imported)
        let roundTripped = OptimizationQueue.importFromNotes(formatted)
        XCTAssertEqual(roundTripped.items.count, 3)
        XCTAssertEqual(roundTripped.items.filter { $0.status == .completed }.count, 1)
        XCTAssertEqual(roundTripped.items.filter { $0.status == .pending }.count, 2)
        XCTAssertEqual(roundTripped.items[2].title, "自我进化")
    }

    /// 测试夹具。时间钉在 epoch，避免排序吃 Date。
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

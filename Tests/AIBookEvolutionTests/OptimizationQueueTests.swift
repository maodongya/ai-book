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

    func testImportFromNotesReturnsEmptyForInvalidContent() {
        let queue = OptimizationQueue.importFromNotes("没有编号命令\n纯文本")
        XCTAssertTrue(queue.items.isEmpty)
    }

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

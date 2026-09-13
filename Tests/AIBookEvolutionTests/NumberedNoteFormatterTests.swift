import XCTest
@testable import AIBookEvolution

/// 编号笔记格式化：完成项带「已完成：」，待办只有编号和标题。
final class NumberedNoteFormatterTests: XCTestCase {
    /// 完成项前缀「已完成：」，待办不能带这个前缀。
    func testFormatsCompletedAndPendingItems() {
        let now = Date()
        let queue = OptimizationQueue(
            version: 1,
            updatedAt: now,
            lastAnalysisAt: nil,
            items: [
                OptimizationItem(
                    id: UUID(),
                    number: 1,
                    title: "左右分栏",
                    rationale: "",
                    category: .featureGap,
                    priority: .medium,
                    risk: .low,
                    suggestedFiles: [],
                    source: .user,
                    status: .completed,
                    pinnedAt: nil,
                    createdAt: now,
                    updatedAt: now,
                    completionSummary: nil
                ),
                OptimizationItem(
                    id: UUID(),
                    number: 2,
                    title: "增加朗读",
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
                ),
            ]
        )

        let text = NumberedNoteFormatter.format(queue)
        XCTAssertTrue(text.contains("1、已完成：左右分栏")) // 完成态必须能被 Parser 再认回
        XCTAssertTrue(text.contains("2、增加朗读")) // 待办不能写成「已完成」
    }

    /// format → parse 编号和完成态不能丢。
    func testRoundTripWithParser() {
        let notes = """
        1、已完成：左右分栏
        2、增加朗读
        """
        let parsed = NumberedNoteParser.parse(notes)
        let now = Date()
        let queue = OptimizationQueue(
            version: 1,
            updatedAt: now,
            lastAnalysisAt: nil,
            items: parsed.map { command in
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
                    completionSummary: nil
                )
            }
        )

        let formatted = NumberedNoteFormatter.format(queue)
        let reparsed = NumberedNoteParser.parse(formatted)
        XCTAssertEqual(reparsed.map(\.number), [1, 2]) // 编号按原文，不重排
        XCTAssertTrue(reparsed[0].isCompleted) // 「已完成：」必须保住
        XCTAssertFalse(reparsed[1].isCompleted) // 无前缀就是待办
        XCTAssertEqual(reparsed[1].title, "增加朗读")
    }
}

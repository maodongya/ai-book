import XCTest
@testable import AIBookEvolution

final class NumberedNoteFormatterTests: XCTestCase {
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
        XCTAssertTrue(text.contains("1、已完成：左右分栏"))
        XCTAssertTrue(text.contains("2、增加朗读"))
    }

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
        XCTAssertEqual(reparsed.map(\.number), [1, 2])
        XCTAssertTrue(reparsed[0].isCompleted)
        XCTAssertFalse(reparsed[1].isCompleted)
        XCTAssertEqual(reparsed[1].title, "增加朗读")
    }
}

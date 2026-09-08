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

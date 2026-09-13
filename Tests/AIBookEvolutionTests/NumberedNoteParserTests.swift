import XCTest
@testable import AIBookEvolution

/// 编号笔记解析：顿号/点号都认，无编号行丢掉。
final class NumberedNoteParserTests: XCTestCase {
    /// 「1、」和「3.」都算命令；「前言」丢掉。
    func testParsesNumberedLinesAndCompletionMarkers() {
        let notes = """
        前言不是命令
        1、已完成：左右分栏
        2、增加朗读
        3. 优化咬字
        """
        let parsed = NumberedNoteParser.parse(notes)
        XCTAssertEqual(parsed.map(\.number), [1, 2, 3]) // 点号那行也要进来
        XCTAssertTrue(parsed[0].isCompleted) // 「已完成：」标记
        XCTAssertFalse(parsed[1].isCompleted) // 无标记默认待办
        XCTAssertEqual(parsed[1].title, "增加朗读")
    }
}

import XCTest
@testable import AIBook

/// 整段覆盖：缺段、合并、分批与截断 JSON 修补。
final class ParagraphTranslationCoverageTests: XCTestCase {
    /// 空译文和缺号都算未覆盖。
    func testMissingIndicesTreatsEmptyAsUncovered() {
        let items = [
            ParagraphTranslationItem(index: 0, translationText: "甲", notes: nil),
            ParagraphTranslationItem(index: 1, translationText: "  ", notes: nil),
        ]
        XCTAssertEqual(
            ParagraphTranslationCoverage.missingIndices(in: items, expectedCount: 3),
            [1, 2]
        )
    }

    /// 后到的非空译文覆盖同号旧译文。
    func testMergePrefersIncomingNonEmpty() {
        let existing = [
            ParagraphTranslationItem(index: 0, translationText: "旧", notes: nil),
        ]
        let incoming = [
            ParagraphTranslationItem(index: 0, translationText: "新", notes: "注"),
            ParagraphTranslationItem(index: 1, translationText: "乙", notes: nil),
        ]
        let merged = ParagraphTranslationCoverage.merge(existing, with: incoming)
        XCTAssertEqual(merged.map { $0.translationText }, ["新", "乙"])
        XCTAssertEqual(merged.first?.notes, "注")
    }

    /// 按固定批大小切段，最后一批可以不足。
    func testBatchesCoverEveryIndexOnce() {
        let batches = ParagraphTranslationCoverage.batches(count: 25, size: 10)
        XCTAssertEqual(batches.map { Array($0) }, [
            Array(0..<10),
            Array(10..<20),
            Array(20..<25),
        ])
    }

    /// 拼回的 JSON 能过严格验收。
    func testEncodedJSONBuildsStrictAlignment() {
        let source = "A\n\nB"
        let json = ParagraphTranslationCoverage.encodedJSON([
            ParagraphTranslationItem(index: 0, translationText: "甲", notes: nil),
            ParagraphTranslationItem(index: 1, translationText: "乙", notes: nil),
        ])
        let result = TranslationAlignmentBuilder.buildStrictParagraph(from: json, source: source)
        guard case .success(let alignment) = result else {
            return XCTFail("encoded JSON must pass strict build")
        }
        XCTAssertEqual(alignment.blocks.map { $0.translationText }, ["甲", "乙"])
    }

    /// 截断的 translations 数组仍保住已经闭合的段。
    func testParseRecoversCompleteItemsFromTruncatedJSON() {
        let truncated = """
        {"mode":"paragraph","translations":[
          {"index":0,"translationText":"甲","notes":null},
          {"index":1,"translationText":"乙"
        """
        let items = TranslationAlignmentBuilder.parseParagraphTranslationItems(from: truncated)
        XCTAssertEqual(items.map { $0.index }, [0])
        XCTAssertEqual(items.first?.translationText, "甲")
    }
}

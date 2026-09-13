import XCTest
@testable import AIBook

final class SourceParagraphIndexTests: XCTestCase {
    func testCountMatchesPromptBuilder() {
        let source = "第一段\n\n第二段\n\n\n第三段"
        XCTAssertEqual(
            TranslationPromptBuilder.countParagraphs(in: source),
            SourceParagraphIndex.build(from: source).count
        )
    }

    func testClassicalQuoteParagraphIsIndexed() {
        let quotePara = """
        子曰："舜其大孝也与！德为圣人，尊为天子，富有四海之内，宗庙飨之，子孙保之。故大德必得其位，必得其禄，必得其名，必得其寿。故天之生物，必因其材而笃焉。故栽者培之，倾者覆之。《诗》曰：'嘉乐君子，宪宪令德。宜民宜人，受禄于天。保佑命之，自天申之。'故大德者必受命。"
        """
        let source = "前文。\n\n\(quotePara)\n\n后文。"
        let index = SourceParagraphIndex.build(from: source)
        XCTAssertEqual(index.count, 3)
        XCTAssertTrue(index.slices[1].text.contains("舜其大孝"))
        let ns = source as NSString
        let r = index.slices[1].range
        XCTAssertEqual(ns.substring(with: r), index.slices[1].text)
    }
}

final class ParagraphAlignmentValidatorTests: XCTestCase {
    func testStrictBuildAcceptsTranslationsJSON() throws {
        let source = "Alpha\n\nBeta"
        let json = """
        {"mode":"paragraph","translations":[
          {"index":0,"translationText":"甲","notes":null},
          {"index":1,"translationText":"乙","notes":null}
        ]}
        """
        let result = TranslationAlignmentBuilder.buildStrictParagraph(from: json, source: source)
        guard case .success(let alignment) = result else {
            return XCTFail("expected success")
        }
        XCTAssertTrue(alignment.strictParagraphValidated)
        XCTAssertEqual(alignment.provenance, .aiParagraphJSON)
        XCTAssertEqual(alignment.blocks.filter { $0.level == .paragraph }.count, 2)
    }

    func testStrictBuildRejectsMissingParagraph() {
        let source = "A\n\nB"
        let json = """
        {"mode":"paragraph","translations":[{"index":0,"translationText":"一","notes":null}]}
        """
        let result = TranslationAlignmentBuilder.buildStrictParagraph(from: json, source: source)
        guard case .failure(.emptyTranslation(let index)) = result else {
            return XCTFail("expected empty translation at second paragraph")
        }
        XCTAssertEqual(index, 1)
    }

    func testStrictBuildDoesNotApplyPlainTextFallback() {
        let source = "Only one paragraph"
        let plain = "纯译文\n\n第二段"
        let result = TranslationAlignmentBuilder.buildStrictParagraph(from: plain, source: source)
        guard case .failure = result else {
            return XCTFail("plain text must not produce alignment")
        }
    }
}

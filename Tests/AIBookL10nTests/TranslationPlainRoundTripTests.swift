import XCTest
@testable import AIBook

/// 保存为 UTF-8 后再打开，应能恢复严格段对齐。
final class TranslationPlainRoundTripTests: XCTestCase {
    func testParseRenderedExportFormatSplitsNotes() {
        let plain = """
        【文章】

        译一
        （注一）

        译二
        """
        let sections = TranslationContentFormatter.parseRenderedParagraphSections(from: plain)
        XCTAssertEqual(sections?.map(\.translationText), ["译一", "译二"])
        XCTAssertEqual(sections?.first?.note, "注一")
    }

    func testRebuiltRenderMatchesExportedPlain() {
        let source = "第一段\n\n第二段"
        let json = """
        {"mode":"paragraph","translations":[
          {"index":0,"translationText":"译一","notes":"注一"},
          {"index":1,"translationText":"译二","notes":null}
        ]}
        """
        guard case .success(let alignment) = TranslationAlignmentBuilder.buildStrictParagraph(
            from: json,
            source: source
        ) else {
            return XCTFail("expected strict alignment")
        }
        let plain = TranslationContentFormatter.renderIndexed(alignment, title: "文章").content
        let index = SourceParagraphIndex.build(from: source)
        guard let sections = TranslationContentFormatter.parseRenderedParagraphSections(from: plain) else {
            return XCTFail("parse failed")
        }
        let blocks = sections.enumerated().map { order, section in
            let slice = index.slices[order]
            return TranslationBlock(
                sourceRange: slice.range,
                sourceText: slice.text,
                translationText: section.translationText,
                note: section.note,
                level: .paragraph,
                order: order
            )
        }
        let rebuilt = TranslationAlignment(
            mode: .paragraph,
            blocks: blocks,
            sourceContentHash: TranslationSourceHasher.hash(source),
            createdAt: Date(),
            isStale: false,
            strictParagraphValidated: true,
            provenance: .importedPlain
        )
        let again = TranslationContentFormatter.render(rebuilt, title: "文章")
        XCTAssertEqual(
            TranslationSourceHasher.normalize(again),
            TranslationSourceHasher.normalize(plain)
        )
    }

    func testRenderedPlainRealignsStrictlyAfterSaveFormat() {
        let source = "第一段\n\n第二段"
        let json = """
        {"mode":"paragraph","translations":[
          {"index":0,"translationText":"译一","notes":"注一"},
          {"index":1,"translationText":"译二","notes":null}
        ]}
        """
        guard case .success(var alignment) = TranslationAlignmentBuilder.buildStrictParagraph(
            from: json,
            source: source
        ) else {
            return XCTFail("expected strict alignment")
        }
        let rendered = TranslationContentFormatter.renderIndexed(alignment, title: "文章")
        alignment.blocks = rendered.blocks

        let plain = rendered.content
        XCTAssertEqual(TranslationContentFormatter.parseRenderedParagraphSections(from: plain)?.count, 2)
        guard let outcome = TranslationAligner.align(
            source: source,
            translation: plain,
            displayTitle: "文章"
        ) else {
            return XCTFail("expected round-trip align")
        }

        XCTAssertTrue(outcome.alignment.strictParagraphValidated)
        XCTAssertEqual(
            outcome.alignment.blocks.filter { $0.level == .paragraph }.map { $0.translationText },
            ["译一", "译二"]
        )
        XCTAssertEqual(outcome.alignment.blocks.first?.note, "注一")
        XCTAssertNil(outcome.renderedContent)
    }
}

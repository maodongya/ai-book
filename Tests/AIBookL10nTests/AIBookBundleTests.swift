import XCTest
@testable import AIBook

final class AIBookBundleTests: XCTestCase {
    func testZipRoundTrip() throws {
        let archived = try ZipArchive.archive(files: [
            "source/source.txt": Data("甲\n\n乙".utf8),
            "manifest.json": Data("{}".utf8),
        ])
        let files = try ZipArchive.extract(archived)
        XCTAssertEqual(files["source/source.txt"], Data("甲\n\n乙".utf8))
        XCTAssertEqual(files["manifest.json"], Data("{}".utf8))
    }

    func testRejectsParentPath() {
        XCTAssertFalse(ZipArchive.isSafePath("../secret.txt"))
        XCTAssertFalse(ZipArchive.isSafePath("/tmp/a.txt"))
    }

    func testBundleKeepsMultipleLanguages() throws {
        var bundle = AIBookBundle(title: "文章", source: "第一段\n\n第二段", languages: [:])
        bundle.upsert(
            languageID: "en",
            translationText: "One\n\nTwo",
            translationAlignment: nil,
            replaceTranslationAlignment: true
        )
        bundle.upsert(
            languageID: "ja",
            explanationText: "解説",
            explanationAlignment: nil,
            replaceExplanationAlignment: true
        )
        bundle.upsert(
            languageID: "en",
            explanationText: "Notes",
            replaceExplanationAlignment: false
        )

        let decoded = try AIBookBundle.decode(try bundle.encoded())
        XCTAssertEqual(decoded.source, "第一段\n\n第二段")
        XCTAssertEqual(decoded.languages["en"]?.translationText, "One\n\nTwo")
        XCTAssertEqual(decoded.languages["en"]?.explanationText, "Notes")
        XCTAssertEqual(decoded.languages["ja"]?.explanationText, "解説")
        XCTAssertNil(decoded.languages["ja"]?.translationText)
    }

    func testOpenSelectionUsesOnlyTheLanguageInSettings() {
        var bundle = AIBookBundle(title: "文章", source: "原文", languages: [:])
        bundle.upsert(languageID: "zh-Hans", translationText: "译文", explanationText: "讲解")
        bundle.upsert(languageID: "en", translationText: "Translation", explanationText: "Notes")

        let matched = bundle.openSelection(translationLanguageID: "zh-Hans", explanationLanguageID: "zh-Hans")
        XCTAssertEqual(matched.translation?.translationText, "译文")
        XCTAssertEqual(matched.explanation?.explanationText, "讲解")

        let missing = bundle.openSelection(translationLanguageID: "ja", explanationLanguageID: "ja")
        XCTAssertNil(missing.translation)
        XCTAssertNil(missing.explanation)
    }

    func testOpenSelectionKeepsTranslationAndExplanationOnTheirOwnSettings() {
        var bundle = AIBookBundle(title: "文章", source: "原文", languages: [:])
        bundle.upsert(languageID: "en", translationText: "Translation")
        bundle.upsert(languageID: "ja", explanationText: "解説")

        let selection = bundle.openSelection(translationLanguageID: "en", explanationLanguageID: "ja")
        XCTAssertEqual(selection.translation?.translationText, "Translation")
        XCTAssertNil(selection.translation?.explanationText)
        XCTAssertEqual(selection.explanation?.explanationText, "解説")
        XCTAssertNil(selection.explanation?.translationText)
    }

    func testUpsertKeepsOtherLanguage() throws {
        var bundle = AIBookBundle(title: "文章", source: "原文", languages: [:])
        bundle.upsert(languageID: "ja", translationText: "訳")
        bundle.upsert(languageID: "en", translationText: "Tr")
        let decoded = try AIBookBundle.decode(try bundle.encoded())
        XCTAssertEqual(decoded.languages["ja"]?.translationText, "訳")
        XCTAssertEqual(decoded.languages["en"]?.translationText, "Tr")
    }
}

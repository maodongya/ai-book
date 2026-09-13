import XCTest
@testable import AIBook

/// 翻译提示：每种目标语都带稳定语言名和 BCP-47，JSON 字段名不译。
final class TranslationPromptBuilderTests: XCTestCase {
    /// followApp 除外，每种具体语言都写入 promptLanguageName 和 bcp47。
    func testEveryConcreteLanguageAddsStableTargetMetadata() {
        let languages = TranslationTargetLanguage.allCases.filter {
            $0 != .followAppLanguage
        }

        for language in languages {
            let prompt = TranslationPromptBuilder.build(
                source: "原文",
                existingPlan: nil,
                instruction: nil,
                mode: .paragraph,
                targetLanguage: language
            )
            XCTAssertTrue(prompt.contains(language.promptLanguageName), language.rawValue)
            XCTAssertTrue(prompt.contains(language.bcp47Identifier), language.rawValue)
            XCTAssertTrue(prompt.contains("JSON 字段名保持不变"), language.rawValue) // 模型不得把字段名译走
        }
    }

    /// 目标简中时，古文必须译成现代白话，不能只「翻译」。
    func testSimplifiedChineseRequiresModernVernacularForClassicalChinese() {
        let prompt = TranslationPromptBuilder.build(
            source: "学而时习之",
            existingPlan: nil,
            instruction: nil,
            mode: .paragraph,
            targetLanguage: .zhHans
        )

        XCTAssertTrue(prompt.contains("现代简体中文"))
        XCTAssertTrue(prompt.contains("古文、文言文或古典汉语"))
        XCTAssertTrue(prompt.contains("现代白话文"))
    }

    func testParagraphModeEmbedsIndexAndTranslationsFormat() {
        let source = "第一段\n\n第二段"
        let prompt = TranslationPromptBuilder.build(
            source: source,
            existingPlan: nil,
            instruction: nil,
            mode: .paragraph,
            targetLanguage: .zhHans
        )
        XCTAssertTrue(prompt.contains("【段落索引"))
        XCTAssertTrue(prompt.contains("\"translations\""))
        XCTAssertTrue(prompt.contains("\"index\":0"))
    }

    /// 分批提示只附本批 index，避免模型漏后段。
    func testParagraphModeSubsetOnlyIncludesRequestedIndices() {
        let source = "第一段\n\n第二段\n\n第三段"
        let prompt = TranslationPromptBuilder.build(
            source: source,
            existingPlan: nil,
            instruction: nil,
            mode: .paragraph,
            targetLanguage: .zhHans,
            paragraphIndices: [1, 2]
        )
        XCTAssertTrue(prompt.contains("\"index\":1"))
        XCTAssertTrue(prompt.contains("\"index\":2"))
        XCTAssertFalse(prompt.contains("\"index\":0,\"sourceText\""))
        XCTAssertTrue(prompt.contains("本批"))
        XCTAssertTrue(prompt.contains("第二段"))
        XCTAssertFalse(prompt.contains("\"sourceText\":\"第一段\""))
    }

    /// 逐词和整段两种模式，目标语契约相同。
    func testBothModesCarryTheSameTargetLanguageContract() {
        for mode in [TranslationAlignmentMode.wordByWord, .paragraph] {
            let prompt = TranslationPromptBuilder.build(
                source: "λόγος",
                existingPlan: nil,
                instruction: nil,
                mode: mode,
                targetLanguage: .el
            )
            XCTAssertTrue(prompt.contains("Greek"))
            XCTAssertTrue(prompt.contains("（el）"))
            XCTAssertTrue(prompt.contains("译文、总结、难点和注释"))
        }
    }
}

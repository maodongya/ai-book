import XCTest
@testable import AIBook

final class TranslationPromptBuilderTests: XCTestCase {
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
            XCTAssertTrue(prompt.contains("JSON 字段名保持不变"), language.rawValue)
        }
    }

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

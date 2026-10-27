import XCTest
@testable import AIBook

/// 讲解提示：目标语写进提示，JSON 字段名不译。
final class ExplanationPromptBuilderTests: XCTestCase {
    func testEveryConcreteLanguageAddsStableTargetMetadata() {
        let languages = TranslationTargetLanguage.selectableTargets
        for language in languages {
            let prompt = ExplanationPromptBuilder.build(
                source: "原文",
                targetLanguage: language
            )
            XCTAssertTrue(prompt.contains(language.promptLanguageName), language.rawValue)
            XCTAssertTrue(prompt.contains(language.bcp47Identifier), language.rawValue)
            XCTAssertTrue(prompt.contains("JSON 字段名保持不变"), language.rawValue)
            XCTAssertTrue(prompt.contains("讲解正文"), language.rawValue)
        }
    }

    func testSimplifiedChineseUsesModernVernacular() {
        let prompt = ExplanationPromptBuilder.build(
            source: "学而时习之",
            targetLanguage: .zhHans
        )
        XCTAssertTrue(prompt.contains("现代简体中文"))
        XCTAssertTrue(prompt.contains("现代白话文"))
    }
}

import XCTest
@testable import AIBook

/// 讲解语言：没存过时收成界面语言；多选按菜单顺序。
final class ExplanationTargetLanguageTests: XCTestCase {
    func testMissingSelectionUsesAppLanguage() {
        let suiteName = "ExplanationTargetLanguageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(
            ExplanationTargetLanguageStore.loadSelection(appLanguage: .ja, from: defaults),
            [.ja]
        )
        XCTAssertEqual(
            ExplanationTargetLanguageStore.load(appLanguage: .ja, from: defaults),
            .ja
        )
    }

    func testSelectionKeepsMenuOrderAndDisplayRoundTrips() {
        let suiteName = "ExplanationTargetLanguageTests.selection.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        ExplanationTargetLanguageStore.saveSelection([.ja, .en], to: defaults)
        ExplanationTargetLanguageStore.save(.el, to: defaults)

        XCTAssertEqual(
            ExplanationTargetLanguageStore.loadSelection(appLanguage: .zhHans, from: defaults),
            [.en, .ja]
        )
        XCTAssertEqual(
            ExplanationTargetLanguageStore.load(appLanguage: .zhHans, from: defaults),
            .el
        )
    }

    func testInvalidDisplayFallsBackToAppLanguage() {
        let suiteName = "ExplanationTargetLanguageTests.invalid.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("followAppLanguage", forKey: ExplanationTargetLanguageStore.key)
        XCTAssertEqual(
            ExplanationTargetLanguageStore.load(appLanguage: .de, from: defaults),
            .de
        )
    }
}

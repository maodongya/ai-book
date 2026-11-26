import XCTest

/// 启动参数 `-SnapshotTranslationCompare` 注入对照样例，验证底栏与对照表可访问。
final class AIBookIOSUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSnapshotTranslationCompareShowsCompareGrid() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-SnapshotTranslationCompare")
        app.launch()

        let compareList = app.descendants(matching: .any)["ios.compareList"]
        XCTAssertTrue(compareList.waitForExistence(timeout: 8))

        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "床前")).firstMatch
                .waitForExistence(timeout: 4)
        )
        let englishInGrid = app.textViews.containing(NSPredicate(format: "value CONTAINS %@", "Before")).firstMatch
        let englishInLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Before")).firstMatch
        XCTAssertTrue(englishInGrid.waitForExistence(timeout: 4) || englishInLabel.waitForExistence(timeout: 1))
    }

    func testTabBarSwitchesToExplanation() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-SnapshotTranslationCompare")
        app.launch()

        let explanationTab = app.buttons["ios.tab.explanation"]
        XCTAssertTrue(explanationTab.waitForExistence(timeout: 6))
        explanationTab.tap()

        XCTAssertTrue(explanationTab.isSelected)
    }
}
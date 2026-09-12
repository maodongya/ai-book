import XCTest
@testable import AIBook

final class BookL10nCatalogTests: XCTestCase {
    func testJapaneseNewAction() {
        UserDefaults.standard.set(BookAppLanguage.ja.rawValue, forKey: "aiBook.appLanguage")
        XCTAssertEqual(BookL10n.string("action.new"), "新規")
    }

    func testEnglishNewAction() {
        UserDefaults.standard.set(BookAppLanguage.en.rawValue, forKey: "aiBook.appLanguage")
        XCTAssertEqual(BookL10n.string("action.new"), "New")
    }

    func testChineseNewAction() {
        UserDefaults.standard.set(BookAppLanguage.zhHans.rawValue, forKey: "aiBook.appLanguage")
        XCTAssertEqual(BookL10n.string("action.new"), "新建")
    }
}

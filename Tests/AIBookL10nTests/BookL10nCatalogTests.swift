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

    func testTranslationTargetStringsExistInEveryInterfaceLanguage() {
        let keys = [
            "translation.target.title",
            "translation.target.followApp",
            "translation.target.hint",
        ]
        let languages = BookAppLanguage.allCases.filter { $0 != .system }
        let defaults = UserDefaults.standard
        let original = defaults.string(forKey: "aiBook.appLanguage")
        defer {
            if let original {
                defaults.set(original, forKey: "aiBook.appLanguage")
            } else {
                defaults.removeObject(forKey: "aiBook.appLanguage")
            }
        }

        for language in languages {
            defaults.set(language.rawValue, forKey: "aiBook.appLanguage")
            for key in keys {
                let value = BookL10n.string(key)
                XCTAssertNotEqual(value, key, "\(language.rawValue): \(key)")
                XCTAssertFalse(value.isEmpty, "\(language.rawValue): \(key)")
            }
        }
    }
}

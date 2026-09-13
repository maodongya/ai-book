import XCTest
@testable import AIBook

/// 界面语言表：action.new 三语，翻译设置键各语都有。
final class BookL10nCatalogTests: XCTestCase {
    /// 日语「新建」。
    func testJapaneseNewAction() {
        UserDefaults.standard.set(BookAppLanguage.ja.rawValue, forKey: "aiBook.appLanguage")
        XCTAssertEqual(BookL10n.string("action.new"), "新規")
    }

    /// 英语 New。
    func testEnglishNewAction() {
        UserDefaults.standard.set(BookAppLanguage.en.rawValue, forKey: "aiBook.appLanguage")
        XCTAssertEqual(BookL10n.string("action.new"), "New")
    }

    /// 简中「新建」。
    func testChineseNewAction() {
        UserDefaults.standard.set(BookAppLanguage.zhHans.rawValue, forKey: "aiBook.appLanguage")
        XCTAssertEqual(BookL10n.string("action.new"), "新建")
    }

    /// 翻译目标相关键在每种界面语言都有非空译文，不能回退成 key。
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
                XCTAssertNotEqual(value, key, "\(language.rawValue): \(key)") // 缺词会原样返回 key
                XCTAssertFalse(value.isEmpty, "\(language.rawValue): \(key)")
            }
        }
    }
}

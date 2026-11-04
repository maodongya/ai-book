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

    /// 对齐/锁定按钮在八种界面语言里都是该语言，不能停在英文。
    func testAlignAndLockLabelsUseEachInterfaceLanguage() {
        let expected: [String: [BookAppLanguage: String]] = [
            "translation.alignTranslation": [
                .zhHans: "对齐翻译",
                .en: "Align translation",
                .ja: "翻訳を揃える",
                .de: "Übersetzung ausrichten",
                .fr: "Aligner la traduction",
                .it: "Allinea traduzione",
                .la: "Aligna translationem",
                .el: "Ευθυγράμμιση μετάφρασης",
            ],
            "translation.lock": [
                .zhHans: "锁定翻译",
                .en: "Lock translation",
                .ja: "翻訳を固定",
                .de: "Übersetzung sperren",
                .fr: "Verrouiller la traduction",
                .it: "Blocca traduzione",
                .la: "Claude translationem",
                .el: "Κλείδωμα μετάφρασης",
            ],
            "translation.unlock": [
                .zhHans: "解锁翻译",
                .en: "Unlock translation",
                .ja: "翻訳の固定を解除",
                .de: "Übersetzung entsperren",
                .fr: "Déverrouiller la traduction",
                .it: "Sblocca traduzione",
                .la: "Resera translationem",
                .el: "Ξεκλείδωμα μετάφρασης",
            ],
            "explanation.alignSource": [
                .zhHans: "对齐讲解",
                .en: "Align explanation",
                .ja: "解説を揃える",
                .de: "Erklärung ausrichten",
                .fr: "Aligner l’explication",
                .it: "Allinea spiegazione",
                .la: "Aligna explicationem",
                .el: "Ευθυγράμμιση εξήγησης",
            ],
            "explanation.lock": [
                .zhHans: "锁定讲解",
                .en: "Lock explanation",
                .ja: "解説を固定",
                .de: "Erklärung sperren",
                .fr: "Verrouiller l’explication",
                .it: "Blocca spiegazione",
                .la: "Claude explicationem",
                .el: "Κλείδωμα εξήγησης",
            ],
            "explanation.unlock": [
                .zhHans: "解锁讲解",
                .en: "Unlock explanation",
                .ja: "解説の固定を解除",
                .de: "Erklärung entsperren",
                .fr: "Déverrouiller l’explication",
                .it: "Sblocca spiegazione",
                .la: "Resera explicationem",
                .el: "Ξεκλείδωμα εξήγησης",
            ],
            "translation.tableCompare": [
                .zhHans: "翻译对照",
                .en: "Translation table",
                .ja: "翻訳対照",
                .de: "Übersetzungsvergleich",
                .fr: "Comparaison de traduction",
                .it: "Confronto traduzione",
                .la: "Comparatio translationis",
                .el: "Σύγκριση μετάφρασης",
            ],
            "explanation.tableCompare": [
                .zhHans: "讲解对照",
                .en: "Explanation table",
                .ja: "解説対照",
                .de: "Erklärungsvergleich",
                .fr: "Comparaison d’explication",
                .it: "Confronto spiegazione",
                .la: "Comparatio explicationis",
                .el: "Σύγκριση εξήγησης",
            ],
        ]
        let operationMirrors: [String: String] = [
            "operation.action.alignTranslation": "translation.alignTranslation",
            "operation.action.lockTranslation": "translation.lock",
            "operation.action.unlockTranslation": "translation.unlock",
            "operation.action.alignExplanation": "explanation.alignSource",
            "operation.action.lockExplanation": "explanation.lock",
            "operation.action.unlockExplanation": "explanation.unlock",
            "operation.action.toggleTranslationTable": "translation.tableCompare",
            "operation.action.toggleExplanationTable": "explanation.tableCompare",
        ]
        let defaults = UserDefaults.standard
        let original = defaults.string(forKey: "aiBook.appLanguage")
        defer {
            if let original {
                defaults.set(original, forKey: "aiBook.appLanguage")
            } else {
                defaults.removeObject(forKey: "aiBook.appLanguage")
            }
        }

        for language in BookAppLanguage.allCases where language != .system {
            defaults.set(language.rawValue, forKey: "aiBook.appLanguage")
            for (key, byLanguage) in expected {
                XCTAssertEqual(BookL10n.string(key), byLanguage[language], "\(language.rawValue): \(key)")
            }
            for (operationKey, sourceKey) in operationMirrors {
                XCTAssertEqual(
                    BookL10n.string(operationKey),
                    BookL10n.string(sourceKey),
                    "\(language.rawValue): \(operationKey)"
                )
            }
            let hint = BookL10n.string("help.alignStale")
            XCTAssertTrue(
                hint.contains(expected["translation.alignTranslation"]![language]!),
                "\(language.rawValue) hint missing align translation: \(hint)"
            )
            XCTAssertTrue(
                hint.contains(expected["explanation.alignSource"]![language]!),
                "\(language.rawValue) hint missing align explanation: \(hint)"
            )
        }
    }

    /// 中英不同的文案，日德法意拉希不能再整句等于英文。同形的外来词在允许表里。
    func testOtherLocalesAreNotCopiesOfEnglish() {
        let cognates: Set<String> = [
            "action.ok|ja", "action.ok|de", "action.ok|fr", "action.ok|it", "action.ok|la", "action.ok|el",
            "action.stop|it",
            "language.la|fr",
            "action.pause|de", "action.pause|fr",
            "menu.document|fr",
            "context.label.chat|de", "context.label.chat|it",
            "context.label.input|it",
            "label.provider|it",
            "label.note|fr",
            "evolution.detail.input|it",
            "evolution.detail.error|la",
            "file.articleStem|fr",
        ]
        let languages: [BookAppLanguage] = [.ja, .de, .fr, .it, .la, .el]
        let defaults = UserDefaults.standard
        let original = defaults.string(forKey: "aiBook.appLanguage")
        defer {
            if let original {
                defaults.set(original, forKey: "aiBook.appLanguage")
            } else {
                defaults.removeObject(forKey: "aiBook.appLanguage")
            }
        }

        defaults.set(BookAppLanguage.zhHans.rawValue, forKey: "aiBook.appLanguage")
        let chinese = Dictionary(uniqueKeysWithValues: BookL10nCatalog.testingKeys().map { ($0, BookL10n.string($0)) })
        defaults.set(BookAppLanguage.en.rawValue, forKey: "aiBook.appLanguage")
        let english = Dictionary(uniqueKeysWithValues: chinese.keys.map { ($0, BookL10n.string($0)) })

        for language in languages {
            defaults.set(language.rawValue, forKey: "aiBook.appLanguage")
            for key in chinese.keys where chinese[key] != english[key] {
                let token = "\(key)|\(language.rawValue)"
                if cognates.contains(token) { continue }
                XCTAssertNotEqual(BookL10n.string(key), english[key], token)
            }
        }
    }
}

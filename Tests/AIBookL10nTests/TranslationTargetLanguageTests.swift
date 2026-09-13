import Foundation
import XCTest
@testable import AIBook

/// 翻译目标语：坏值回跟随界面；具体语不跟系统走。
final class TranslationTargetLanguageTests: XCTestCase {
    /// nil/空/未知 rawValue 都当跟随界面，不崩、不猜。
    func testMissingAndInvalidStoredValuesFollowAppLanguage() {
        XCTAssertEqual(TranslationTargetLanguage.migrated(from: nil), .followAppLanguage)
        XCTAssertEqual(TranslationTargetLanguage.migrated(from: ""), .followAppLanguage)
        XCTAssertEqual(TranslationTargetLanguage.migrated(from: "unknown"), .followAppLanguage)
    }

    /// 每个 case 的 rawValue 再 migrated 必须是自己。
    func testEveryRawValueRoundTrips() {
        for language in TranslationTargetLanguage.allCases {
            XCTAssertEqual(
                TranslationTargetLanguage.migrated(from: language.rawValue),
                language
            )
        }
    }

    /// 已选希腊语就固定希腊语，不管界面是日语。
    func testConcreteTargetIgnoresAppAndSystemLanguages() {
        XCTAssertEqual(
            TranslationTargetLanguage.el.resolved(
                appLanguage: .ja,
                systemLocaleIdentifier: "de_DE"
            ),
            .el
        )
    }

    /// 跟随界面：界面日语则目标日语。
    func testFollowAppLanguageResolvesConcreteAppLanguage() {
        XCTAssertEqual(
            TranslationTargetLanguage.followAppLanguage.resolved(
                appLanguage: .ja,
                systemLocaleIdentifier: "de_DE"
            ),
            .ja
        )
    }

    /// 界面=系统时，已知 locale 映到对应目标语。
    func testFollowSystemMapsAllSupportedLocales() {
        let cases: [(String, TranslationTargetLanguage)] = [
            ("zh_CN", .zhHans),
            ("en_US", .en),
            ("ja_JP", .ja),
            ("de_DE", .de),
            ("fr_FR", .fr),
            ("it_IT", .it),
            ("la", .la),
            ("el_GR", .el),
        ]

        for (identifier, expected) in cases {
            XCTAssertEqual(
                TranslationTargetLanguage.followAppLanguage.resolved(
                    appLanguage: .system,
                    systemLocaleIdentifier: identifier
                ),
                expected,
                identifier
            )
        }
    }

    /// 韩语等未做界面的 locale 回英语，不回简中。
    func testUnsupportedSystemLocaleFallsBackToEnglish() {
        XCTAssertEqual(
            TranslationTargetLanguage.followAppLanguage.resolved(
                appLanguage: .system,
                systemLocaleIdentifier: "ko_KR"
            ),
            .en
        )
    }

    /// 独立 suite：空默认跟随；脏值迁回跟随。
    func testStoreSavesLoadsAndMigratesInvalidValues() {
        let suiteName = "TranslationTargetLanguageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(
            TranslationTargetLanguageStore.load(from: defaults),
            .followAppLanguage
        )
        TranslationTargetLanguageStore.save(.el, to: defaults)
        XCTAssertEqual(TranslationTargetLanguageStore.load(from: defaults), .el)

        defaults.set("invalid", forKey: TranslationTargetLanguageStore.key)
        XCTAssertEqual(
            TranslationTargetLanguageStore.load(from: defaults),
            .followAppLanguage
        )
    }
}

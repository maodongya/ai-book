import Foundation
import XCTest
@testable import AIBook

final class TranslationTargetLanguageTests: XCTestCase {
    func testMissingAndInvalidStoredValuesFollowAppLanguage() {
        XCTAssertEqual(TranslationTargetLanguage.migrated(from: nil), .followAppLanguage)
        XCTAssertEqual(TranslationTargetLanguage.migrated(from: ""), .followAppLanguage)
        XCTAssertEqual(TranslationTargetLanguage.migrated(from: "unknown"), .followAppLanguage)
    }

    func testEveryRawValueRoundTrips() {
        for language in TranslationTargetLanguage.allCases {
            XCTAssertEqual(
                TranslationTargetLanguage.migrated(from: language.rawValue),
                language
            )
        }
    }

    func testConcreteTargetIgnoresAppAndSystemLanguages() {
        XCTAssertEqual(
            TranslationTargetLanguage.el.resolved(
                appLanguage: .ja,
                systemLocaleIdentifier: "de_DE"
            ),
            .el
        )
    }

    func testFollowAppLanguageResolvesConcreteAppLanguage() {
        XCTAssertEqual(
            TranslationTargetLanguage.followAppLanguage.resolved(
                appLanguage: .ja,
                systemLocaleIdentifier: "de_DE"
            ),
            .ja
        )
    }

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

    func testUnsupportedSystemLocaleFallsBackToEnglish() {
        XCTAssertEqual(
            TranslationTargetLanguage.followAppLanguage.resolved(
                appLanguage: .system,
                systemLocaleIdentifier: "ko_KR"
            ),
            .en
        )
    }

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

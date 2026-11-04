import XCTest
@testable import AIBook

/// 说明书按界面语言读对应 Markdown，缺译文时回退简体中文。
final class BookUserManualTests: XCTestCase {
    /// 每种界面语言的说明书以该语言标题开头，不能都打开中文稿。
    func testEachInterfaceLanguageLoadsItsOwnManual() {
        let titles = [
            "zh-Hans": "# AIBook 功能说明书",
            "en": "# AIBook User Manual",
            "ja": "# AIBook 機能説明書",
            "de": "# AIBook Benutzerhandbuch",
            "fr": "# Manuel AIBook",
            "it": "# Manuale AIBook",
            "la": "# Manualis AIBook",
            "el": "# Εγχειρίδιο AIBook",
        ]
        for (code, title) in titles {
            let text = BookUserManual.loadMarkdown(languageCode: code)
            XCTAssertTrue(text.hasPrefix(title), "\(code) opened \(text.prefix(40))")
            let url = BookUserManual.resolvedURL(languageCode: code)
            if code == "zh-Hans" {
                XCTAssertEqual(url?.lastPathComponent, "功能说明书.md")
            } else {
                XCTAssertEqual(url?.lastPathComponent, "功能说明书-\(code).md")
            }
        }
    }

    /// 说明书里的按钮、菜单、下拉项必须是界面上的原文，不能另起名字。
    func testManualQuotesLiveControlLabels() {
        let samples = [
            "zh-Hans": ["原文补充", "翻译对照", "对齐翻译", "朗读节奏", "原文全屏", "右全屏", "快速：语速较快"],
            "en": ["Classic supplement", "Word-by-Word", "Full Paragraph", "Right Full Screen", "Focus reading", "Unsaved"],
            "ja": ["原文を補完", "快速", "集中読書", "未保存", "翻訳を揃える"],
            "de": ["Original ergänzen", "Rechts Vollbild", "Fokus Lesen", "Ungesichert", "Übersetzung ausrichten"],
            "fr": ["Compléter l’original", "Plein écran droit", "Lecture focus", "Non enregistré", "Aligner la traduction"],
            "it": ["Integra l’originale", "Schermo destro", "Lettura focus", "Non salvato", "Allinea traduzione"],
            "la": ["Supple originale", "Dextra plena", "Lectio intenta", "Non servatum", "Aligna translationem"],
            "el": ["Συμπλήρωση πρωτοτύπου", "Δεξιά πλήρης", "Εστιασμένη ανάγνωση", "Μη αποθηκευμένο", "Ευθυγράμμιση μετάφρασης"],
        ]
        for (code, labels) in samples {
            let text = BookUserManual.loadMarkdown(languageCode: code)
            for label in labels {
                XCTAssertTrue(text.contains(label), "\(code) manual missing \(label)")
            }
        }
    }

    /// 没有对应文件的语言回退简体中文，不给空白窗。
    func testUnknownLanguageFallsBackToChineseManual() {
        let text = BookUserManual.loadMarkdown(languageCode: "pt")
        XCTAssertTrue(text.hasPrefix("# AIBook 功能说明书"))
        XCTAssertEqual(
            BookUserManual.resourceNames(for: "pt"),
            ["功能说明书-pt", "功能说明书"]
        )
        XCTAssertEqual(
            BookUserManual.resourceNames(for: "zh-Hans"),
            ["功能说明书"]
        )
    }
}

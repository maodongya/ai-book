import XCTest
@testable import AIBookIOS

/// 气泡先向右、再向下，窄屏不并排，阅读页收起气泡。
final class IOSShellTests: XCTestCase {
    /// 按下气泡时菜单还没掉下来。
    @MainActor
    func testOpenPullsRightBeforeTheMenuDrops() {
        let shell = IOSShellModel()
        shell.openMenu()
        XCTAssertTrue(shell.panelExtended)
        XCTAssertFalse(shell.menuDropped)
        XCTAssertFalse(IOSBubbleMotion.menuVisible(opened: true, elapsed: 0.2))
        XCTAssertTrue(IOSBubbleMotion.menuVisible(opened: true, elapsed: IOSBubbleMotion.dropDownDelay))
    }

    /// 拉开之后才允许菜单向下出现。
    @MainActor
    func testRevealMenuWaitsUntilThePanelIsExtended() {
        let shell = IOSShellModel()
        shell.revealMenu()
        XCTAssertFalse(shell.menuDropped)
        shell.openMenu()
        shell.revealMenu()
        XCTAssertTrue(shell.menuDropped)
    }

    /// 菜单顺序是原文、翻译、讲解、设置。
    func testBubbleOrderMatchesTheDesign() {
        XCTAssertEqual(IOSPage.bubbleOrder, [.source, .translation, .explanation, .settings])
    }

    /// iPhone 横屏宽度不并排，iPad 横屏才并排。
    func testPhoneWidthStaysSinglePage() {
        XCTAssertFalse(IOSLayout.usesSideBySide(width: 932))
        XCTAssertTrue(IOSLayout.usesSideBySide(width: 1180))
    }

    /// 进入阅读后气泡消失，返回时回到原来的页。
    @MainActor
    func testReadingHidesTheBubbleAndReturnsToThePreviousPage() {
        let shell = IOSShellModel()
        shell.select(.explanation)
        shell.enterReading()
        XCTAssertEqual(shell.page, .reading)
        XCTAssertFalse(shell.showsBubble)
        shell.exitReading()
        XCTAssertEqual(shell.page, .explanation)
        XCTAssertTrue(shell.showsBubble)
    }

    /// 松手没过三分之一就留在本页。
    func testTurnRequiresAboutOneThirdOfThePage() {
        XCTAssertEqual(IOSReadingTurn.pageDelta(translation: -100, pageWidth: 390), 0)
        XCTAssertEqual(IOSReadingTurn.pageDelta(translation: -140, pageWidth: 390), 1)
        XCTAssertEqual(IOSReadingTurn.pageDelta(translation: 140, pageWidth: 390), -1)
    }

    /// 短于一页的正文仍然有一页。
    func testShortTextIsOneReadingPage() {
        XCTAssertEqual(IOSReadingPages.slices(of: "abc", pageSize: 10), ["abc"])
        XCTAssertEqual(IOSReadingPages.slices(of: "", pageSize: 10), [""])
    }

    /// 讲解提示里必须带上要讲的原文。
    func testExplainPromptCarriesTheSource() {
        let prompt = IOSReadingPrompt.explain(source: "床前明月光", followUp: nil)
        XCTAssertTrue(prompt.user.contains("床前明月光"))
    }

    /// 聊天补全能从 choices 里取出助手正文。
    func testAssistantTextReadsTheFirstChoice() throws {
        let json = #"{"choices":[{"message":{"content":"  明月 "}}]}"#.data(using: .utf8)!
        XCTAssertEqual(try IOSChatClient.assistantText(from: json), "明月")
    }

    /// 「全文讲解」在请求模型前就能对上本地口令。
    func testFullExplainPhraseMapsLocally() {
        let plan = OperationPhraseMatch.localPlan(for: "全文讲解", language: .zhHans)
        XCTAssertEqual(plan?.actions, [.explainFullText])
    }

    /// 行数不同时，多出来的一侧是空字符串，不错位到下一行。
    func testParagraphPairsKeepIndexWhenLengthsDiffer() {
        let pairs = IOSParagraphPairs.pairs(source: "甲\n乙", other: "A")
        XCTAssertEqual(pairs.count, 2)
        XCTAssertEqual(pairs[0].other, "A")
        XCTAssertEqual(pairs[1].source, "乙")
        XCTAssertEqual(pairs[1].other, "")
    }

    /// `.aibook` 写出去再读回来，原文和一种语言的译文都在。
    func testAIBookRoundTripKeepsSourceAndTranslation() throws {
        var bundle = AIBookBundle(title: "静夜思", source: "床前明月光", languages: [:])
        bundle.upsert(languageID: "zh-Hans", translationText: "Bright moon")
        let decoded = try AIBookBundle.decode(try bundle.encoded())
        XCTAssertEqual(decoded.source, "床前明月光")
        XCTAssertEqual(decoded.languages["zh-Hans"]?.translationText, "Bright moon")
    }

    /// 新建原文会清掉未保存的正文和讲解。
    @MainActor
    func testNewDocumentClearsTheOpenBook() {
        let document = IOSDocument()
        document.openText(name: "静夜思", text: "床前明月光")
        document.storeExplanation("注释")
        document.editSource("改过")
        document.newDocument()
        XCTAssertFalse(document.hasSource)
        XCTAssertEqual(document.explanation, "")
        XCTAssertFalse(document.dirty)
    }

    /// 名著补充只取标记之间的正文。
    func testSupplementBodyKeepsTheMarkedPassage() {
        let reply = "说明\n<<<名著补充>>>\n床前明月光\n<<<END>>>\n多余"
        XCTAssertEqual(IOSReadingPrompt.supplementBody(from: reply), "床前明月光")
    }
}

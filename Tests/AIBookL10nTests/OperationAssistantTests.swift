import XCTest
@testable import AIBook

final class OperationPhraseMatchTests: XCTestCase {
    func testExplainFullTextFromASRHomophones() {
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "升腾全文讲解")?.actions, [.explainFullText])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "生成全文讲解")?.actions, [.explainFullText])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "全文讲解")?.actions, [.explainFullText])
    }

    func testExplainSelectionWithoutFullKeyword() {
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "讲解选区")?.actions, [.explainSelection])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "选择讲解")?.actions, [.explainSelection])
    }

    func testReadExplanationFullIsNotExplainFullText() {
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "朗读讲解全文")?.actions, [.readExplanationFull])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "朗读讲解选区")?.actions, [.readExplanationSelection])
    }

    func testButtonTitlesMapToActions() {
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "原文新建")?.actions, [.newDocument])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "新建原文")?.actions, [.newDocument])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "原文打开目录")?.actions, [.openDirectoryPanel])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "打开原文目录")?.actions, [.openDirectoryPanel])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "原文打开")?.actions, [.openFilePanel])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "打开原文")?.actions, [.openFilePanel])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "原文保存")?.actions, [.save])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "保存原文")?.actions, [.save])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "原文另存为")?.actions, [.saveAs])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "原文全选")?.actions, [.selectAllLeft])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "全选原文")?.actions, [.selectAllLeft])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "原文补充")?.actions, [.supplementClassic])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "原文名著补充")?.actions, [.supplementClassic])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "阅读模式")?.actions, [.toggleReadingMode])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "原文阅读")?.actions, [.toggleReadingMode])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "阅读原文")?.actions, [.toggleReadingMode])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "原文朗读全文")?.actions, [.readOriginalFull])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "新建讲解")?.actions, [.newExplanation])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "保存讲解")?.actions, [.saveExplanation])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "清空讲解")?.actions, [.clearExplanation])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "全选讲解")?.actions, [.selectAllExplanation])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "对齐讲解")?.actions, [.alignExplanation])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "逐字翻译")?.actions, [.translateWordByWord])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "整段翻译")?.actions, [.translateParagraph])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "保存翻译")?.actions, [.saveTranslation])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "对齐翻译")?.actions, [.alignTranslation])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "全选翻译")?.actions, [.selectAllRight])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "朗读原文全文")?.actions, [.readOriginalFull])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "朗读翻译全文")?.actions, [.readTranslationFull])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "停止朗读讲解")?.actions, [.stopSpeech])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "停止讲解")?.actions, [.stopCurrentRun])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "原文全屏")?.actions, [.setPaneFocus("leading")])
    }

    func testEnglishButtonsAndChinesePhrasesBothMatch() {
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "Reading mode", language: .en)?.actions, [.toggleReadingMode])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "阅读模式", language: .en)?.actions, [.toggleReadingMode])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "Save source", language: .en)?.actions, [.save])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "原文保存", language: .en)?.actions, [.save])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "包存", language: .en)?.actions, [.save])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "Save source as", language: .en)?.actions, [.saveAs])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "Save source as AIBook", language: .en)?.actions, [.saveAsAIBook(nil)])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "Open source folder", language: .en)?.actions, [.openDirectoryPanel])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "Open source", language: .en)?.actions, [.openFilePanel])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "Save explanation", language: .en)?.actions, [.saveExplanation])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "Explain Selection", language: .en)?.actions, [.explainSelection])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "Explain All", language: .en)?.actions, [.explainFullText])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "Word-by-Word", language: .en)?.actions, [.translateWordByWord])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "Read source selection", language: .en)?.actions, [.readOriginalSelection])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "Read all source", language: .en)?.actions, [.readOriginalFull])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "Stop explanation", language: .en)?.actions, [.stopSpeech])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "停止讲解", language: .en)?.actions, [.stopCurrentRun])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "Unlock explanation", language: .en)?.actions, [.unlockExplanation])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "読書モード", language: .ja)?.actions, [.toggleReadingMode])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "原文新建", language: .ja)?.actions, [.newDocument])
    }

    func testSaveAsAIBookFromTruncatedASR() {
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "保存为 AI boo")?.actions, [.saveAsAIBook(nil)])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "另存为 aibook")?.actions, [.saveAsAIBook(nil)])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "保存为AI Book1")?.actions, [.saveAsAIBook("AI Book1")])
    }

    func testSavePhrasesWithoutLLM() {
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "保存")?.actions, [.save])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "保\u{200b}存")?.actions, [.save])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "保·存")?.actions, [.save])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "保存一下")?.actions, [.save])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "存盘")?.actions, [.save])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "存一下")?.actions, [.save])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "包存")?.actions, [.save])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "报存")?.actions, [.save])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "另存为")?.actions, [.saveAs])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "保存为备份")?.actions, [.saveAs])
        XCTAssertEqual(OperationPhraseMatch.localPlan(for: "保存选区")?.actions, [.saveSelectionAs])
    }

    func testPlannerUsesLocalMatchWithoutCallingClient() async throws {
        let client = FakeOperationClient(result: LLMCompletionResult(
            content: "",
            reasoning: nil,
            toolCalls: [],
            usage: .zero
        ))
        let plan = try await OperationPlanner.plan(
            utterance: "升腾全文讲解",
            snapshot: OperationContextSnapshot.make(
                fileName: "a.txt",
                hasDocumentPath: false,
                isDirty: false,
                selection: "一句",
                experienceMode: .learning,
                paneFocus: .both,
                rightPage: .readingAssistant,
                assistantPanel: .explanation,
                explanationLanguage: .zhHans,
                translationLanguage: .zhHans,
                enabledExplanationLanguages: [.zhHans],
                enabledTranslationLanguages: [.zhHans],
                speech: .idle,
                isRunning: false,
                libraryFileNames: []
            ),
            client: client
        )

        XCTAssertEqual(plan.actions, [.explainFullText])
        XCTAssertEqual(client.callCount, 0)
    }
}

final class OperationPlanParserTests: XCTestCase {
    func testParsesToolCallsInOrderAndDropsUnknownNames() {
        let plan = OperationPlanParser.parse(toolCalls: [
            LLMToolCall(id: "1", name: "explainSelection", arguments: "{}"),
            LLMToolCall(id: "2", name: "deleteFile", arguments: "{}"),
            LLMToolCall(id: "3", name: "setPaneFocus", arguments: #"{"focus":"leading"}"#),
        ])

        XCTAssertEqual(plan.actions, [
            .explainSelection,
            .setPaneFocus("leading"),
        ])
    }

    func testEmptyToolCallsAndEmptyJSONAreEmptyPlans() {
        XCTAssertEqual(OperationPlanParser.parse(toolCalls: []).actions, [])
        XCTAssertEqual(OperationPlanParser.parse(content: #"{"actions":[]}"#).actions, [])
        XCTAssertEqual(OperationPlanParser.parse(content: "不是 JSON").actions, [])
    }

    func testParsesFencedJSON() {
        let content = """
        ```json
        {"actions":[{"name":"save","arguments":{}}]}
        ```
        """
        XCTAssertEqual(OperationPlanParser.parse(content: content).actions, [.save])
    }

    func testParsesJSONContentAndDropsInvalidArguments() {
        let content = """
        {"actions":[
          {"name":"openLibraryFile","arguments":{"query":"笔记"}},
          {"name":"setPaneFocus","arguments":{"focus":"sideways"}},
          {"name":"showExplanationLanguage","arguments":{"language":"ja"}},
          {"name":"save","arguments":{}}
        ]}
        """
        let plan = OperationPlanParser.parse(content: content)
        XCTAssertEqual(plan.actions, [
            .openLibraryFile("笔记"),
            .showExplanationLanguage("ja"),
            .save,
        ])
    }

    func testPrefersToolCallsOverContent() {
        let plan = OperationPlanParser.parse(
            toolCalls: [LLMToolCall(id: "1", name: "save", arguments: "{}")],
            content: #"{"actions":[{"name":"explainFullText","arguments":{}}]}"#
        )
        XCTAssertEqual(plan.actions, [.save])
    }
}

final class OperationContextSnapshotTests: XCTestCase {
    func testExcerptAndLibraryAreCappedAndBodyIsAbsent() {
        let selection = String(repeating: "前", count: 80) + String(repeating: "后", count: 20)
        let bodyTail = "正文不会进快照-UNIQUE"
        let names = (1...50).map { "book-\($0).txt" }

        let snapshot = OperationContextSnapshot.make(
            fileName: "a.txt",
            hasDocumentPath: true,
            isDirty: false,
            selection: selection,
            experienceMode: .learning,
            paneFocus: .both,
            rightPage: .readingAssistant,
            assistantPanel: .explanation,
            explanationLanguage: .zhHans,
            translationLanguage: .en,
            enabledExplanationLanguages: [.zhHans, .ja],
            enabledTranslationLanguages: [.en],
            speech: .idle,
            isRunning: false,
            libraryFileNames: names
        )

        XCTAssertEqual(snapshot.selectionExcerpt, String(repeating: "前", count: 80))
        XCTAssertEqual(snapshot.libraryFiles.count, 40)
        XCTAssertTrue(snapshot.libraryTruncated)
        XCTAssertEqual(snapshot.libraryFiles.first, "book-1.txt")

        let encoded = snapshot.jsonString()
        XCTAssertFalse(encoded.contains(bodyTail))
        XCTAssertFalse(encoded.contains("后"))
        XCTAssertFalse(encoded.contains("book-50.txt"))
    }
}

final class OperationExecutorTests: XCTestCase {
    func testSkipsMissingSelectionAndContinues() async {
        var performed: [OperationAction] = []
        let log = await OperationExecutor.execute(
            plan: OperationPlan(actions: [.explainSelection, .save]),
            state: OperationRuntimeState(),
            confirm: { _ in true },
            perform: { performed.append($0) }
        )

        XCTAssertEqual(performed, [.save])
        XCTAssertEqual(log.skipped.map(\.reason), [.noSelection])
    }

    func testLibraryMatchMustBeUnique() async {
        var performed: [OperationAction] = []
        let state = OperationRuntimeState(libraryFileNames: ["甲.txt", "甲.md", "乙.txt"])
        _ = await OperationExecutor.execute(
            plan: OperationPlan(actions: [
                .openLibraryFile("甲"),
                .openLibraryFile("没有"),
                .openLibraryFile("乙.txt"),
            ]),
            state: state,
            confirm: { _ in true },
            perform: { performed.append($0) }
        )

        XCTAssertEqual(performed, [.openLibraryFile("乙.txt")])
    }

    func testEvolutionWaitsForConfirmationAndCancelStopsTheRest() async {
        var performed: [OperationAction] = []
        _ = await OperationExecutor.execute(
            plan: OperationPlan(actions: [.save, .startEvolution, .analyzeOptimizations]),
            state: OperationRuntimeState(hasBody: true),
            confirm: { _ in false },
            perform: { performed.append($0) }
        )

        XCTAssertEqual(performed, [.save])
    }

    func testRunningAllowsStopAndSpeechButSkipsExplanation() async {
        var performed: [OperationAction] = []
        let log = await OperationExecutor.execute(
            plan: OperationPlan(actions: [.explainFullText, .stopSpeech, .stopCurrentRun]),
            state: OperationRuntimeState(hasBody: true, isRunning: true, speech: .speaking),
            confirm: { _ in true },
            perform: { performed.append($0) }
        )

        XCTAssertEqual(performed, [.stopSpeech, .stopCurrentRun])
        XCTAssertEqual(log.skipped.map(\.reason), [.busy])
    }

    func testDisabledLanguageDropsExplanationInTheSamePlan() async {
        var performed: [OperationAction] = []
        _ = await OperationExecutor.execute(
            plan: OperationPlan(actions: [
                .showExplanationLanguage("ja"),
                .explainSelection,
                .readOriginalFull,
            ]),
            state: OperationRuntimeState(
                hasSelection: true,
                hasBody: true,
                enabledExplanationLanguages: [.zhHans]
            ),
            confirm: { _ in true },
            perform: { performed.append($0) }
        )

        XCTAssertEqual(performed, [.readOriginalFull])
    }

    func testShowLanguageRequiresExistingContent() async {
        var performed: [OperationAction] = []
        let log = await OperationExecutor.execute(
            plan: OperationPlan(actions: [.showTranslationLanguage("en")]),
            state: OperationRuntimeState(enabledTranslationLanguages: [.en]),
            confirm: { _ in true },
            perform: { performed.append($0) }
        )

        XCTAssertTrue(performed.isEmpty)
        XCTAssertEqual(log.skipped.map(\.reason), [.languageContentMissing])
    }
}

final class OperationPlannerTests: XCTestCase {
    func testPlansFromToolCallsWithoutASecondRound() async throws {
        let client = FakeOperationClient(result: LLMCompletionResult(
            content: #"{"actions":[{"name":"save","arguments":{}}]}"#,
            reasoning: nil,
            toolCalls: [LLMToolCall(id: "1", name: "explainSelection", arguments: "{}")],
            usage: .zero
        ))
        let plan = try await OperationPlanner.plan(
            utterance: "打开文件", // 不走本地口令，才能验到工具调用
            snapshot: OperationContextSnapshot.make(
                fileName: "a.txt",
                hasDocumentPath: false,
                isDirty: false,
                selection: "一句",
                experienceMode: .learning,
                paneFocus: .both,
                rightPage: .readingAssistant,
                assistantPanel: .explanation,
                explanationLanguage: .zhHans,
                translationLanguage: .zhHans,
                enabledExplanationLanguages: [.zhHans],
                enabledTranslationLanguages: [.zhHans],
                speech: .idle,
                isRunning: false,
                libraryFileNames: []
            ),
            client: client
        )

        XCTAssertEqual(plan.actions, [.explainSelection])
        XCTAssertEqual(client.callCount, 1)
        XCTAssertFalse(client.lastUserMessage.contains("全文正文"))
    }
}

@MainActor
final class OperationAssistantModelTests: XCTestCase {
    func testDismissDuringUnderstandingCancelsAndAllowsAnotherHold() async {
        let speech = ScriptedOperationSpeech(transcript: "打开文件")
        let client = HangingOperationClient()
        let model = OperationAssistantModel(speech: speech)
        model.makeTurn = {
            OperationTurn(
                snapshot: OperationContextSnapshot.make(
                    fileName: "a.txt",
                    hasDocumentPath: false,
                    isDirty: false,
                    selection: "",
                    experienceMode: .learning,
                    paneFocus: .both,
                    rightPage: .readingAssistant,
                    assistantPanel: .explanation,
                    explanationLanguage: .zhHans,
                    translationLanguage: .zhHans,
                    enabledExplanationLanguages: [.zhHans],
                    enabledTranslationLanguages: [.zhHans],
                    speech: .idle,
                    isRunning: false,
                    libraryFileNames: []
                ),
                state: OperationRuntimeState(),
                client: client,
                perform: { _ in }
            )
        }

        model.beginHold()
        let task = Task { await model.endHold() }
        defer { task.cancel() }

        let ready = Date().addingTimeInterval(2)
        let understanding = BookL10n.format("operation.understanding", "打开文件")
        while model.statusText != understanding, Date() < ready {
            await Task.yield()
        }
        XCTAssertEqual(model.statusText, understanding)

        model.dismissStatus() // 理解中关掉应取消这一轮，而不是被忽略
        XCTAssertEqual(model.statusText, BookL10n.string("operation.stopped"))
        model.beginHold()
        XCTAssertTrue(model.isListening)

        let cancelDeadline = Date().addingTimeInterval(2)
        while !client.wasCancelled, Date() < cancelDeadline {
            await Task.yield()
        }
        XCTAssertTrue(client.wasCancelled)
        await task.value
    }
}

@MainActor
private final class ScriptedOperationSpeech: OperationSpeechCapturing {
    var transcript: String

    init(transcript: String) {
        self.transcript = transcript
    }

    func start() throws {}

    func stop() async -> String { transcript }

    func setPartialHandler(_ handler: @escaping (String) -> Void) {}
}

final class OperationSpeechLocaleTests: XCTestCase {
    func testUsesInterfaceLanguageBeforeChinese() {
        let locales = [
            Locale(identifier: "en-US"),
            Locale(identifier: "zh-CN"),
            Locale(identifier: "ja-JP"),
        ]
        let picked = OperationSpeechLocale.resolve(uiIdentifier: "en", supported: locales) { _ in true }
        XCTAssertEqual(picked?.identifier, "en-US")
    }

    func testLatinFallsBackToSimplifiedChinese() {
        let locales = [
            Locale(identifier: "en-US"),
            Locale(identifier: "zh-TW"),
            Locale(identifier: "zh-CN"),
        ]
        let picked = OperationSpeechLocale.resolve(uiIdentifier: "la", supported: locales) { _ in true }
        XCTAssertEqual(picked?.identifier, "zh-CN")
    }

    func testSkipsUnavailableThenUsesSystem() {
        let locales = [
            Locale(identifier: "el-GR"),
            Locale(identifier: "fr-FR"),
        ]
        let picked = OperationSpeechLocale.resolve(
            uiIdentifier: "de",
            supported: locales,
            currentIdentifier: "fr-FR"
        ) { locale in
            locale.identifier == "fr-FR" // 德文和简体都没有，才用本机法文
        }
        XCTAssertEqual(picked?.identifier, "fr-FR")
    }
}

private final class HangingOperationClient: OperationCompletionClient, @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var wasCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    private func markCancelled() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    func complete(userMessage: String, tools: [[String: Any]]) async throws -> LLMCompletionResult {
        _ = userMessage
        _ = tools
        do {
            try await Task.sleep(nanoseconds: 5_000_000_000) // 不取消就会一直占着「正在理解」
        } catch {
            markCancelled()
            throw error
        }
        throw CancellationError()
    }
}

private final class FakeOperationClient: OperationCompletionClient {
    var result: LLMCompletionResult
    var callCount = 0
    var lastUserMessage = ""

    init(result: LLMCompletionResult) {
        self.result = result
    }

    func complete(userMessage: String, tools: [[String: Any]]) async throws -> LLMCompletionResult {
        callCount += 1
        lastUserMessage = userMessage
        _ = tools
        return result
    }
}

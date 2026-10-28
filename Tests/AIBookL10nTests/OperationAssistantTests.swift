import XCTest
@testable import AIBook

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
            utterance: "讲解选区",
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

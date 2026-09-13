#!/usr/bin/env python3
"""Build Phase B ReadingViewModel + sessions from .monolith backup."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
READING = ROOT / "Sources/AIBook/Reading"
MONO = READING / "ReadingViewModel.swift.monolith"
PARTS = ROOT / "scripts" / "split_out"


def read_mono() -> list[str]:
    return MONO.read_text(encoding="utf-8").splitlines(keepends=True)


def fix_argument_labels(text: str) -> str:
    for old, new in (
        ("host.document.fileContent:", "fileContent:"),
        ("host.document.selectedText:", "selectedText:"),
        ("host.document.fileName:", "fileName:"),
        ("host.document.currentFileURL:", "currentFileURL:"),
        ("translation.lessonPlanContent:", "lessonPlanContent:"),
        ("translation.translationAlignment:", "translationAlignment:"),
        ("translation.translationTableViewEnabled:", "translationTableViewEnabled:"),
        ("assistant.readingPromptMessages:", "readingPromptMessages:"),
        ("evolution.evolutionPromptMessages:", "evolutionPromptMessages:"),
        ("assistant.readingChatInput:", "readingChatInput:"),
        ("evolution.evolutionChatInput:", "evolutionChatInput:"),
        ("assistant.readingAssistantPanel:", "readingAssistantPanel:"),
        ("assistant.readingMessages:", "readingMessages:"),
    ):
        text = text.replace(old, new)
    text = text.replace("host.assistant.host.assistant.", "host.assistant.")
    text = text.replace("host.selectReadingAssistantPanel", "host.assistant.selectReadingAssistantPanel")
    text = text.replace("host.showTransientSaveMessage", "host.document.showTransientSaveMessage")
    text = re.sub(r"(?<![.\w])exportContent\(", "host.document.exportContent(", text)
    text = re.sub(r"\bfunc host\.document\.exportContent\(", "func exportContent(", text)
    text = re.sub(r"\bprivate func host\.document\.exportContent\(", "func exportContent(", text)
    text = text.replace("func stopExplanationSpeech {", "func stopExplanationSpeech() {")
    text = text.replace('BookL10n.string("vm.filename.translationSuffix"))"\n\n}', 'BookL10n.string("vm.filename.translationSuffix"))"\n    }\n\n}')
    text = text.replace(
        "try? await Task.sleep(nanoseconds: 200_000_000)\n            }\n        }\n\n}",
        "try? await Task.sleep(nanoseconds: 200_000_000)\n            }\n        }\n    }\n\n}",
    )
    return text


def normalize_method_body(chunk: str) -> str:
    lines = chunk.splitlines(keepends=True)
    out: list[str] = []
    for line in lines:
        if line.startswith("    "):
            out.append(line)
        elif line.strip():
            out.append("    " + line)
        else:
            out.append(line)
    return "".join(out)


def rewrite_chunk(chunk: str, session: str) -> str:
    chunk = re.sub(r"\bEvolutionRunKind\b", "ReadingEvolutionRunKind", chunk)
    chunk = re.sub(r"\bPromptContext\b", "ReadingPromptContext", chunk)
    chunk = chunk.replace("Self.untitledMarker", "ReadingViewModel.untitledMarker")
    chunk = chunk.replace("Self.defaultWelcomeMessage", "ReadingAssistantSession.defaultWelcomeMessage")
    chunk = chunk.replace("Self.defaultEvolutionWelcomeMessage", "ReadingEvolutionSession.defaultEvolutionWelcomeMessage")

    lines = chunk.splitlines(keepends=True)
    out: list[str] = []
    for line in lines:
        stripped = line.lstrip()
        if stripped.startswith("func ") or stripped.startswith("private func ") or stripped.startswith("var ") or stripped.startswith("private var "):
            out.append(line)
            continue
        # property / call rewrites inside body
        l = line
        if session != "vm":
            for host_prop in (
                "isRunning", "isLoading", "errorMessage", "activeTask", "rightPageTab",
                "streamingThinking", "streamingResponse", "streamingToolStatus", "streamingToolSteps",
                "isRestoringSession", "suppressReplySpeech", "llmService", "cursorService",
                "showSettings", "showBookSettings", "showUserManual",
            ):
                l = re.sub(rf"(?<![.\w]){host_prop}(?![.\w:])", f"host.{host_prop}", l)

        if session != "document":
            for prop in ("fileContent", "fileName", "selectedText", "isDocumentOpen", "isDirty", "currentFileURL", "savedContent", "selectedTextRange", "lastCommittedSelectionText", "lastCommittedSelectionRange", "lastCommittedLessonPlanSelectedText", "lastCommittedExplanationPanelSelectedText", "directoryBrowserSessions", "showDirectoryBrowser"):
                l = re.sub(rf"(?<![.\w]){prop}(?![.\w])", f"host.document.{prop}", l)
        if session != "mode":
            for prop in ("experienceMode", "readingPageTexts", "readingSourcePageRanges", "readingSpreadIndex", "readingSpreadCount", "readingPageCount", "pendingReadingSourcePage", "lastReadingPageContentSize"):
                l = re.sub(rf"(?<![.\w]){prop}(?![.\w])", f"host.mode.{prop}", l)
        if session != "translation":
            for prop in ("lessonPlanContent", "lessonPlanSelectedText", "translationAlignment", "translationTableViewEnabled", "translationTableScrollTargetID", "translationTableHighlightedBlockID", "translationTableFocusTranslationBlockID", "isApplyingAlignment", "sourceTextScrollProxy", "translationTextScrollProxy", "translationScrollSync", "showsTranslationTableView", "canUseTranslationTableView", "shouldSyncTranslationScroll"):
                l = re.sub(rf"(?<![.\w]){prop}(?![.\w])", f"host.translation.{prop}", l)
        if session != "assistant":
            for prop in ("chatMessages", "readingChatInput", "readingAssistantPanel", "readingAssistantActiveTask", "explanationSelectionText", "explanationPanelSelectedText", "explanationSelectAllSignal", "readingPromptMessages", "isSpeakingExplanation", "isExplanationSpeechPaused", "currentSpeechSource"):
                l = re.sub(rf"(?<![.\w]){prop}(?![.\w:])", f"host.assistant.{prop}", l)
        if session == "translation":
            l = re.sub(r"(?<![.\w])readingChatInput(?![.\w:])", "host.assistant.readingChatInput", l)
            l = re.sub(r"(?<![.\w])beginRun\(", "host.beginRun(", l)
        if session != "evolution":
            for prop in ("evolutionChatInput", "optimizationQueue", "evolutionRunKind", "evolutionLastRequestId", "executingEvolutionCommandNumber", "isEvolutionRebuilding", "evolutionRebuildStatus", "evolutionSessionTokensConsumed", "evolutionAgentContextTokens", "showsExecutionTrace", "evolutionPromptMessages", "autoEvolutionTask", "didScheduleAutoEvolution"):
                l = re.sub(rf"(?<![.\w]){prop}(?![.\w:])", f"host.evolution.{prop}", l)

        if session == "vm":
            vm_map = {
                "readingPromptMessages": "assistant.readingPromptMessages",
                "evolutionPromptMessages": "evolution.evolutionPromptMessages",
                "readingChatInput": "assistant.readingChatInput",
                "evolutionChatInput": "evolution.evolutionChatInput",
                "chatMessages": "assistant.chatMessages",
                "readingAssistantPanel": "assistant.readingAssistantPanel",
                "lessonPlanContent": "translation.lessonPlanContent",
                "translationAlignment": "translation.translationAlignment",
                "translationTableViewEnabled": "translation.translationTableViewEnabled",
                "currentFileURL": "document.currentFileURL",
                "fileContent": "document.fileContent",
                "selectedText": "document.selectedText",
                "loadFile": "document.loadFile",
                "ensureEvolutionWelcome": "evolution.ensureEvolutionWelcome",
                "ensureEvolutionUsesCursor": "evolution.ensureEvolutionUsesCursor",
                "rebuildTranslationAlignment": "translation.rebuildTranslationAlignment",
                "repairCollapsedParagraphAlignmentIfNeeded": "translation.repairCollapsedParagraphAlignmentIfNeeded",
                "syncTranslationScrollPresentation": "translation.syncTranslationScrollPresentation",
                "canUseTranslationTableView": "translation.canUseTranslationTableView",
                "syncExplanationSelectionText": "assistant.syncExplanationSelectionText",
                "stopExplanationSpeech": "assistant.stopExplanationSpeech",
                "isTranslationHistoryMessage": "assistant.isTranslationHistoryMessage",
                "revertRunningOptimization": "evolution.revertRunningOptimization",
                "recordEvolutionCursorEstimate": "evolution.recordEvolutionCursorEstimate",
                "recordEvolutionTokenUsage": "evolution.recordEvolutionTokenUsage",
                "updateEvolutionAgentContextTokens": "evolution.updateEvolutionAgentContextTokens",
                "clearEvolutionExecutionState": "evolution.clearEvolutionExecutionState",
                "evolutionLiveToolLabel": "evolutionLiveToolLabel",
                "executingEvolutionCommandNumber": "evolution.executingEvolutionCommandNumber",
                "showsExecutionTrace": "evolution.showsExecutionTrace",
                "evolutionSessionTokensConsumed": "evolution.evolutionSessionTokensConsumed",
                "evolutionAgentContextTokens": "evolution.evolutionAgentContextTokens",
                "evolutionLastRequestId": "evolution.evolutionLastRequestId",
                "explanationSelectionText": "assistant.explanationSelectionText",
                "explanationPanelSelectedText": "assistant.explanationPanelSelectedText",
                "lastCommittedExplanationPanelSelectedText": "document.lastCommittedExplanationPanelSelectedText",
            }
            for k, v in vm_map.items():
                l = re.sub(rf"(?<![.\w]){k}(?![.\w:])", v, l)

        l = l.replace("host.host.", "host.")
        l = l.replace("host.evolution.showsExecutionTrace:", "showsExecutionTrace:")
        l = l.replace("host.evolution.evolutionRunKind:", "evolutionRunKind:")
        l = l.replace("host.streamingThinking:", "streamingThinking:")
        l = l.replace("host.streamingResponse:", "streamingResponse:")
        l = l.replace("host.document.currentFileURL:", "currentFileURL:")
        l = re.sub(r"readmeNotesStore", "ReadmeNotesStore.shared", l)
        out.append(l)
    return "".join(out)


def wrap_session(name: str, doc: str, props: str, part_file: str, extra: str = "") -> str:
    part = (PARTS / part_file).read_text(encoding="utf-8").rstrip()
    part_lines = part.splitlines()
    if part_lines and part_lines[-1].strip() == "}":
        part_lines.pop()
    part = "\n".join(part_lines) + "\n"
    if part_file == "mode.swift.part":
        part = re.sub(
            r"\n    var cursorContextUsage: CursorContextUsage \{[\s\S]*?\n    var canRunEvolution: Bool \{[\s\S]*?\n    \}\n\s*$",
            "\n",
            part,
            count=1,
        )
    if part_file == "translation.swift.part":
        mono_lines = read_mono()
        full_offset = "".join(mono_lines[2827:2859])
        part = re.sub(
            r"    private func sourceRangeOffsetInFileContent\(\) -> Int \{[\s\S]*?    private func refreshTranslationAlignmentStaleState",
            full_offset + "\n\n    private func refreshTranslationAlignmentStaleState",
            part,
            count=1,
        )
        if "shouldSyncTranslationScroll" not in part:
            part += "\n" + "".join(mono_lines[2860:2868])
    session_key = {
        "ReadingDocumentSession": "document",
        "ReadingModeSession": "mode",
        "ReadingTranslationSession": "translation",
        "ReadingAssistantSession": "assistant",
        "ReadingEvolutionSession": "evolution",
    }[name]
    if part_file == "evolution.swift.part":
        part = part.replace(
            "    private var speakingRefreshTask: Task<Void, Never>?\n    private var suppressReplySpeech = false\n",
            "",
        )
        part = re.sub(
            r"\n    private var hasEvolutionConversation: Bool \{[\s\S]*?\n    \}\n",
            "\n",
            part,
            count=1,
        )
        part = re.sub(
            r"\n    var displayFileName: String \{[\s\S]*?\n    func evolutionTokenBudget",
            "\n\n    func evolutionTokenBudget",
            part,
            count=1,
        )
        part = re.sub(
            r"\n    var canClearReadingContext: Bool \{[\s\S]*?\n    private func exportEvolutionCommands",
            "\n\n    private func exportEvolutionCommands",
            part,
            count=1,
        )
    if part_file == "translation.swift.part":
        part = re.sub(
            r"\n    var showsTranslationTableView: Bool \{[\s\S]*?    \}\n\n\n    private func syncTranslationScrollPresentation",
            "\n\n    private func syncTranslationScrollPresentation",
            part,
            count=1,
        )
    body = rewrite_chunk(normalize_method_body(part), session_key)
    body = re.sub(r"(?<![.\w])stopExplanationSpeech\(\)", "host.assistant.stopExplanationSpeech()", body)
    body = body.replace("func host.assistant.stopExplanationSpeech()", "func stopExplanationSpeech")
    body = body.replace("readingChatInput.trimmingCharacters", "host.assistant.readingChatInput.trimmingCharacters")
    body = body.replace("readingChatInput =", "host.assistant.readingChatInput =")
    host_methods = (
        "contextHistory", "apiHistory", "appendDisplayedMessage", "appendDisplayOnlyMessage",
        "appendPromptMessage", "updatePromptMessage", "removePromptMessage", "isDisplaying",
        "activePromptContext", "selectRightPageTab", "selectReadingAssistantPanel", "fetchAssistantReply",
        "beginRun", "resetStreamingState", "sendMessage", "persistChatSession", "syncDisplayedChatMessages",
        "guardEvolutionTokenLimit", "recordEvolutionCursorEstimate",
        "clearEvolutionExecutionState", "revertRunningOptimization",
        "loadFile", "showTransientSaveMessage", "message",
    )
    for meth in host_methods:
        body = re.sub(rf"(?<![.\w]){meth}\(", f"host.{meth}(", body)
    body = re.sub(r"\bfunc host\.(\w+)\(", r"func \1(", body)
    body = re.sub(r"\bprivate func host\.(\w+)\(", r"private func \1(", body)
    body = body.replace("host.host.", "host.")
    body = re.sub(
        r"\n    private var speakingRefreshTask: Task<Void, Never>\?\n    private var suppressReplySpeech = false\s*$",
        "",
        body,
    )
    body = fix_argument_labels(body)
    if name == "ReadingDocumentSession":
        body = body.replace("host.loadFile(", "loadFile(")
        body = body.replace("private func showTransientSaveMessage", "func showTransientSaveMessage")
        body = body.replace("private func exportContent", "func exportContent")
        for fn in (
            "confirmReplaceOptimizationQueue", "syncLeftPageWithEvolutionCommands",
            "syncLeftPageFromOptimizationQueue", "syncOptimizationQueueFromLeftPageIfNeeded",
        ):
            body = body.replace(f"private func {fn}", f"func {fn}")
    if name == "ReadingAssistantSession":
        body = body.replace(
            "            }\n        }\n\n}",
            "            }\n        }\n    }\n\n}",
        )
    if name == "ReadingEvolutionSession":
        for prefix in ("recordEvolution", "updateEvolution", "guardEvolution", "ensureEvolution", "persistOptimization", "loadOptimization", "evolutionTokenBudget"):
            body = body.replace(f"host.{prefix}", prefix)
        body = body.replace("confirmReplaceOptimizationQueue(", "host.document.confirmReplaceOptimizationQueue(")
        body = body.replace("syncLeftPageWithEvolutionCommands(", "host.document.syncLeftPageWithEvolutionCommands(")
        body = body.replace("syncLeftPageFromOptimizationQueue(", "host.document.syncLeftPageFromOptimizationQueue(")
        body = body.replace("hasExplanationContent", "host.assistant.hasExplanationContent")
    return f"""import AIBookEvolution
import AppKit
import Combine
import Foundation

@MainActor
/// {doc}
final class {name}: ObservableObject {{
    unowned var host: ReadingViewModel!

{props}
{extra}
{body}
}}
"""


DOCUMENT_PROPS = """
    @Published var fileContent = "" {
        didSet {
            isDirty = fileContent != savedContent
            scheduleAutoSaveIfNotes()
            if !host.isRestoringSession, !host.translation.isApplyingAlignment {
                host.translation.refreshTranslationAlignmentStaleState()
            }
        }
    }
    @Published var fileName = ReadingViewModel.untitledMarker
    @Published private(set) var isDocumentOpen = false
    @Published var selectedText = ""
    var lastCommittedSelectionText = ""
    private var lastCommittedSelectionRange: NSRange?
    @Published private(set) var leftSelectAllSignal = UUID()
    @Published private(set) var rightSelectAllSignal = UUID()
    var lastCommittedLessonPlanSelectedText = ""
    var lastCommittedExplanationPanelSelectedText = ""
    @Published private(set) var isDirty = false
    @Published var showDirectoryBrowser = false
    @Published var directoryBrowserSessions: [DirectoryBrowserRootSession] = []
    @Published var selectedDirectorySessionID: UUID?
    @Published private(set) var lastSaveMessage: String?
    var currentFileURL: URL?
    private var savedContent = ""
    private var selectedTextRange: NSRange?
    private var autoSaveTask: Task<Void, Never>?
    private var saveMessageTask: Task<Void, Never>?
    private let readmeNotesStore = ReadmeNotesStore.shared

    var displayFileName: String {
        guard isDocumentOpen || currentFileURL != nil || !fileContent.isEmpty else {
            return BookL10n.string("vm.noFileOpen")
        }
        let name = currentFileURL?.lastPathComponent ?? fileName
        return isDirty ? "\\(name) •" : name
    }

    var isEditingNotes: Bool { currentFileURL == nil }
"""

MODE_PROPS = """
    @Published var experienceMode: ReadingExperienceMode = .learning
    @Published private(set) var readingPageTexts: [String] = []
    @Published private(set) var readingSourcePageRanges: [NSRange] = []
    @Published var readingSpreadIndex: Int = 0 {
        didSet {
            guard readingSpreadIndex != oldValue else { return }
            persistReadingSpreadIndex()
        }
    }
    private var pendingReadingSourcePage: Int?
    private var lastReadingPageContentSize: CGSize?
    private let readingPositionKeyPrefix = "aiBook.reading.spread."
    private let readingSourcePageKeyPrefix = "aiBook.reading.sourcePage."

    var canEnterReadingMode: Bool {
        !host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var readingSpreadCount: Int { max(1, (readingPageTexts.count + 1) / 2) }
    var readingPageCount: Int { readingPageTexts.count }
"""

TRANSLATION_PROPS = """
    @Published var lessonPlanSelectedText = ""
    @Published var lessonPlanContent = "" {
        didSet {
            if !isApplyingAlignment {
                refreshTranslationAlignmentStaleState(fromManualEdit: true)
            }
            host.persistChatSession()
        }
    }
    @Published var translationAlignment: TranslationAlignment? {
        didSet {
            translationScrollSync.resetAnchors()
            if isApplyingAlignment { return }
            syncTranslationScrollPresentation()
            host.persistChatSession()
        }
    }
    @Published var translationTableViewEnabled = false {
        didSet {
            syncTranslationScrollPresentation()
            host.persistChatSession()
        }
    }
    @Published var translationTableScrollTargetID: UUID?
    @Published var translationTableHighlightedBlockID: UUID?
    @Published var translationTableFocusTranslationBlockID: UUID?
    let sourceTextScrollProxy = SelectableTextViewProxy()
    let translationTextScrollProxy = SelectableTextViewProxy()
    let translationScrollSync = TranslationScrollSync()
    var isApplyingAlignment = false

    var canAlignTranslationWithSource: Bool {
        !host.isRunning
            && translationAlignment?.isLocked != true
            && !lessonPlanSourceText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isTranslationAlignmentLocked: Bool { translationAlignment?.isLocked == true }

    var translationAlignmentStatusText: String? {
        guard let alignment = translationAlignment else { return nil }
        if alignment.isStale { return BookL10n.string("vm.align.stale") }
        var parts = [BookL10n.format("vm.align.anchored", alignment.anchoredBlockCount, alignment.blocks.count)]
        if alignment.isLocked { parts.append(BookL10n.string("vm.align.locked")) }
        return parts.joined(separator: " · ")
    }

    var showsTranslationTableView: Bool { translationTableViewEnabled && canUseTranslationTableView }

    var canUseTranslationTableView: Bool {
        guard let alignment = translationAlignment, !alignment.isStale else { return false }
        return alignment.blocks.contains { $0.level == .word || $0.level == .phrase || $0.level == .paragraph }
    }

    var shouldSyncTranslationScroll: Bool {
        host.mode.experienceMode == .learning
            && host.rightPageTab == .readingAssistant
            && host.assistant.readingAssistantPanel == .translation
            && showsTranslationTableView
            && translationAlignment != nil
            && translationAlignment?.isStale == false
    }
"""

ASSISTANT_PROPS = """
    static var defaultWelcomeMessage: ChatMessage {
        ChatMessage(role: .assistant, content: ReadingAssistant.welcomeMessage)
    }

    @Published var chatMessages: [ChatMessage] = [] {
        didSet { host.persistChatSession() }
    }
    @Published var readingChatInput = "" {
        didSet { host.persistChatSession() }
    }
    @Published var readingAssistantPanel: ReadingAssistantPanel = .explanation {
        didSet {
            guard !host.isRestoringSession else { return }
            host.persistChatSession()
        }
    }
    @Published var readingAssistantActiveTask: ReadingAssistantPanel?
    @Published var explanationSelectionText = ""
    @Published var explanationPanelSelectedText = ""
    @Published private(set) var explanationSelectAllSignal = UUID()
    @Published private(set) var isSpeakingExplanation = false
    @Published private(set) var isExplanationSpeechPaused = false
    @Published private(set) var currentSpeechSource: SpeechSource?
    var readingPromptMessages: [ChatMessage] = [ReadingAssistantSession.defaultWelcomeMessage]
    private var speakingRefreshTask: Task<Void, Never>?

    var effectiveSelectedText: String {
        let live = host.document.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return host.document.lastCommittedSelectionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var effectiveLessonPlanSelectedText: String {
        let live = host.translation.lessonPlanSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return host.document.lastCommittedLessonPlanSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var effectiveExplanationPanelSelectedText: String {
        let live = explanationPanelSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return host.document.lastCommittedExplanationPanelSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canReadAloud: Bool {
        !effectiveSelectedText.isEmpty
            || !host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasExplanationContent: Bool {
        readingPromptMessages.contains { message in
            message.role == .assistant && !isReadingWelcomeMessage(message)
        }
    }

    var explanationDisplayMessages: [ChatMessage] {
        chatMessages.filter { shouldDisplayInExplanationPanel($0) }
    }
"""

EVOLUTION_PROPS = """
    static var defaultEvolutionWelcomeMessage: ChatMessage {
        ChatMessage(role: .assistant, content: EvolutionAssistant.welcomeMessage)
    }

    @Published var evolutionChatInput = "" {
        didSet { host.persistChatSession() }
    }
    @Published var optimizationQueue = OptimizationQueue.empty
    @Published private(set) var evolutionRunKind: ReadingEvolutionRunKind = .none
    @Published private(set) var evolutionLastRequestId: String?
    @Published var executingEvolutionCommandNumber: Int?
    @Published var isEvolutionRebuilding = false
    @Published var evolutionRebuildStatus = ""
    @Published private(set) var evolutionSessionTokensConsumed = 0
    @Published private(set) var evolutionAgentContextTokens = 0
    @Published private(set) var showsExecutionTrace = false
    private let optimizationQueueStore = OptimizationQueueStore(
        fileURL: OptimizationQueueStore.defaultFileURL
    )
    private var autoEvolutionTask: Task<Void, Never>?
    private var didScheduleAutoEvolution = false
    var evolutionPromptMessages: [ChatMessage] = []

    var evolutionStatusLabel: String? { SelfEvolution.statusLabel(from: optimizationQueue) }
    var evolutionItems: [OptimizationItem] { optimizationQueue.items.sorted { $0.number < $1.number } }
    var hasPendingOptimization: Bool { optimizationQueue.nextPending() != nil }

    var hasEvolutionConversation: Bool {
        evolutionPromptMessages.contains { !isEvolutionWelcomeMessage($0) }
    }
"""


def build_vm() -> str:
    mono = read_mono()
    text = "".join(mono)
    # orchestrator + vm parts rewritten for sessions
    orch = (PARTS / "orchestrator.swift.part").read_text(encoding="utf-8")
    vm_part = (PARTS / "vm.swift.part").read_text(encoding="utf-8")
    vm_part = re.sub(
        r"\n    /// AI 进化页是否展示 Agent 执行轨迹（Cursor）。\n    var showsEvolutionExecutionTrace: Bool \{[\s\S]*?\n    \}\n",
        "\n",
        vm_part,
        count=1,
    )
    combined = rewrite_chunk(normalize_method_body(orch + vm_part), "vm")

    # Add computed properties chunk from mono (lines 412-469, 1817-1835, 1854-1872)
    computed = """
    var cursorContextUsage: CursorContextUsage {
        CursorContextCalculator.usage(
            fileContent: document.fileContent,
            selectedText: document.selectedText,
            history: assistant.readingPromptMessages,
            input: assistant.readingChatInput,
            contextPercent: AppSettings.shared.cursorContextPercent
        )
    }

    var llmContextUsage: CursorContextUsage {
        CursorContextCalculator.usage(
            fileContent: document.fileContent,
            selectedText: document.selectedText,
            history: assistant.readingPromptMessages,
            input: assistant.readingChatInput,
            contextPercent: AppSettings.shared.bookContextPercent,
            limitCharacters: LLMContextLimits.maxCharacters
        )
    }

    var evolutionLiveToolLabel: String? {
        guard isRunning, evolution.showsExecutionTrace else { return nil }
        if let last = streamingToolSteps.last {
            let name = EvolutionToolLabels.localizedToolName(last.name)
            if last.status == .running {
                return BookL10n.format("vm.tool.running", name)
            }
            return BookL10n.format("vm.tool.done", name)
        }
        if !streamingToolStatus.isEmpty { return streamingToolStatus }
        if !streamingThinking.isEmpty { return BookL10n.string("vm.thinking") }
        return nil
    }

    var evolutionContextUsage: CursorContextUsage {
        CursorContextCalculator.usage(
            fileContent: document.fileContent,
            selectedText: document.selectedText,
            history: evolution.evolutionPromptMessages,
            input: evolution.evolutionChatInput,
            contextPercent: AppSettings.shared.cursorContextPercent,
            limitCharacters: CursorContextLimits.maxCharacters
        )
    }

    var evolutionTokenBudget: ModelTokenBudget {
        evolution.evolutionTokenBudget(additionalPrompt: nil)
    }

    var canRunEvolution: Bool { !evolutionTokenBudget.isOverLimit }

    var showsEvolutionExecutionTrace: Bool { AppSettings.shared.isCursorRunnable }

    var isAnalyzing: Bool { isRunning && evolution.evolutionRunKind == .analysis }

    var canSaveEvolutionCommands: Bool { !evolution.optimizationQueue.items.isEmpty }
    var canOpenEvolutionCommands: Bool { !isRunning }

    var canClearReadingContext: Bool {
        assistant.hasExplanationContent
            || !assistant.readingChatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canClearAIContext: Bool {
        evolution.hasEvolutionConversation
            || !evolution.evolutionChatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || evolution.evolutionSessionTokensConsumed > 0
            || evolution.evolutionAgentContextTokens > 0
    }

"""

    combined = combined.replace("private func beginRun", "func beginRun", 1)
    combined = combined.replace("private func resetStreamingState", "func resetStreamingState", 1)
    for name in (
        "persistChatSession", "restoreChatSession", "syncDisplayedChatMessages", "appendDisplayedMessage",
        "appendDisplayOnlyMessage", "appendPromptMessage", "updatePromptMessage", "removePromptMessage",
        "apiHistory", "contextHistory", "isDisplaying", "activePromptContext", "sendMessage",
        "fetchAssistantReply", "fetchCursorReply", "fetchLLMReply", "handleLLMStreamEvent",
        "handleCursorStreamEvent", "applyToolStepUpdate", "resolvedToolStepsForMessage",
    ):
        combined = combined.replace(f"private func {name}", f"func {name}", 1)
    combined = combined.replace("private var activePromptContext", "var activePromptContext", 1)
    combined = combined.replace("evolutionAgentContextTokens = 0", "evolution.evolutionAgentContextTokens = 0", 1)
    combined = combined.replace("self.showsExecutionTrace = showsExecutionTrace", "evolution.showsExecutionTrace = showsExecutionTrace", 1)
    combined = combined.replace("showsExecutionTrace = false", "evolution.showsExecutionTrace = false", 1)
    combined = combined.replace("readingAssistantActiveTask = nil", "assistant.readingAssistantActiveTask = nil", 1)

    header = """import AIBookEvolution
import AppKit
import Combine
import Foundation

// Note: ReadingViewModel orchestrates child sessions.

@MainActor
/// 双页读书编排：左页原文、右页讲解/翻译/进化，以及 AI 与朗读请求的状态机。
final class ReadingViewModel: ObservableObject {
    static let untitledMarker = "未命名"

    private struct AssistantReplyOutcome {
        let text: String
        let thinking: String?
        let fallbackNotice: String?
    }

    let document = ReadingDocumentSession()
    let mode = ReadingModeSession()
    let translation = ReadingTranslationSession()
    let assistant = ReadingAssistantSession()
    let evolution = ReadingEvolutionSession()

    @Published var rightPageTab: RightPageTab = .readingAssistant {
        didSet {
            guard !isRestoringSession else { return }
            syncDisplayedChatMessages()
            persistChatSession()
        }
    }
    @Published var isLoading = false
    @Published var isRunning = false
    @Published var streamingThinking = ""
    @Published var streamingResponse = ""
    @Published var streamingToolStatus = ""
    @Published var streamingToolSteps: [ExecutionStep] = []
    @Published var errorMessage: String?
    @Published var showSettings = false
    @Published var showBookSettings = false
    @Published var showUserManual = false

    private let llmService = LLMService()
    private let cursorService = CursorService()
    private let chatSessionStore = ChatSessionStore.shared
    var isRestoringSession = false
    var activeTask: Task<Void, Never>?
    private var suppressReplySpeech = false
    private var cancellables = Set<AnyCancellable>()

"""

    init_block = """
    init() {
        document.host = self
        mode.host = self
        translation.host = self
        assistant.host = self
        evolution.host = self
        wireSessionChangeForwarding()
        translation.translationScrollSync.sourceView = translation.sourceTextScrollProxy
        translation.translationScrollSync.translationView = translation.translationTextScrollProxy
        translation.syncTranslationScrollPresentation()
        ExplanationSpeechReader.shared.onSpeakingStateChange = { [weak self] in
            self?.assistant.syncExplanationSpeechState()
        }
        document.loadReadmeNotes()
        evolution.loadOptimizationQueue()
        evolution.ensureEvolutionWelcome()
        restoreChatSession()
        syncDisplayedChatMessages()
        translation.refreshTranslationAlignmentStaleState()
        persistChatSession()
        document.restoreDirectoryBrowserSessions()
    }

    private func wireSessionChangeForwarding() {
        for child in [document as any ObservableObject, mode, translation, assistant, evolution] {
            child.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

"""

    # Fix combined chunk - map host.document etc for vm session rewrite
    combined = rewrite_chunk(combined, "vm")
    combined = combined.replace("host.document.", "document.")
    combined = combined.replace("host.mode.", "mode.")
    combined = combined.replace("host.translation.", "translation.")
    combined = combined.replace("host.assistant.", "assistant.")
    combined = combined.replace("host.evolution.", "evolution.")
    combined = combined.replace("host.host.", "host.")
    combined = fix_argument_labels(combined)

    return header + init_block + computed + combined + "}\n"


def main() -> None:
    sessions = [
        ("ReadingDocumentSession.swift", "ReadingDocumentSession", "左页文档会话：打开/保存、选区、目录浏览与 readme 笔记状态。", DOCUMENT_PROPS, "document.swift.part"),
        ("ReadingModeSession.swift", "ReadingModeSession", "阅读模式会话：学习/阅读体验切换、分页与 spread 索引持久化。", MODE_PROPS, "mode.swift.part"),
        ("ReadingTranslationSession.swift", "ReadingTranslationSession", "翻译会话：译文内容、对齐、表格滚动与翻译 API 调用链。", TRANSLATION_PROPS, "translation.swift.part"),
        ("ReadingAssistantSession.swift", "ReadingAssistantSession", "读书助手会话：讲解/名著补充、对话消息、朗读与输入框。", ASSISTANT_PROPS, "assistant.swift.part"),
        ("ReadingEvolutionSession.swift", "ReadingEvolutionSession", "AI 进化会话：优化队列、分析/进化请求与 token 预算。", EVOLUTION_PROPS, "evolution.swift.part"),
    ]
    for fname, cls, doc, props, part in sessions:
        (READING / fname).write_text(wrap_session(cls, doc, props, part), encoding="utf-8")
    (READING / "ReadingViewModel.swift").write_text(build_vm(), encoding="utf-8")
    types = """import Foundation

enum ReadingPromptContext {
    case reading
    case evolution
}

enum ReadingEvolutionRunKind {
    case none
    case analysis
    case evolution
    case followUp
}
"""
    (READING / "ReadingViewModelTypes.swift").write_text(types, encoding="utf-8")
    (READING / "ReadingMessageOrchestrator.swift").unlink(missing_ok=True)
    print("Built Phase B files")


if __name__ == "__main__":
    main()

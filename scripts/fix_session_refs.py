#!/usr/bin/env python3
"""Post-process generated session files with host/session reference fixes."""
from __future__ import annotations

import re
from pathlib import Path

READING = Path(__file__).resolve().parents[1] / "Sources/AIBook/Reading"

HOST_PROPS = [
    "isRunning", "isLoading", "errorMessage", "activeTask", "rightPageTab",
    "streamingThinking", "streamingResponse", "streamingToolStatus", "streamingToolSteps",
    "suppressReplySpeech", "isRestoringSession", "llmService", "cursorService",
]

SESSION_PROPS = {
    "document": {
        "fileContent", "fileName", "isDocumentOpen", "selectedText", "leftSelectAllSignal",
        "rightSelectAllSignal", "isDirty", "showDirectoryBrowser", "directoryBrowserSessions",
        "selectedDirectorySessionID", "lastSaveMessage", "currentFileURL", "savedContent",
        "selectedTextRange", "lastCommittedSelectionText", "lastCommittedSelectionRange",
        "displayFileName", "isEditingNotes",
    },
    "mode": {
        "experienceMode", "readingPageTexts", "readingSourcePageRanges", "readingSpreadIndex",
        "canEnterReadingMode", "readingSpreadCount", "readingPageCount", "pendingReadingSourcePage",
        "lastReadingPageContentSize",
    },
    "translation": {
        "lessonPlanSelectedText", "lessonPlanContent", "translationAlignment",
        "translationTableViewEnabled", "translationTableScrollTargetID",
        "translationTableHighlightedBlockID", "translationTableFocusTranslationBlockID",
        "isApplyingAlignment", "sourceTextScrollProxy", "translationTextScrollProxy",
        "translationScrollSync",
    },
    "assistant": {
        "chatMessages", "readingChatInput", "readingAssistantPanel", "readingAssistantActiveTask",
        "explanationSelectionText", "explanationPanelSelectedText", "explanationSelectAllSignal",
        "isSpeakingExplanation", "isExplanationSpeechPaused", "currentSpeechSource",
        "readingPromptMessages", "speakingRefreshTask",
    },
    "evolution": {
        "evolutionChatInput", "optimizationQueue", "evolutionRunKind", "evolutionLastRequestId",
        "executingEvolutionCommandNumber", "isEvolutionRebuilding", "evolutionRebuildStatus",
        "evolutionSessionTokensConsumed", "evolutionAgentContextTokens", "showsExecutionTrace",
        "evolutionPromptMessages", "autoEvolutionTask", "didScheduleAutoEvolution",
        "optimizationQueueStore",
    },
}

PROP_BLOCKS = {
    "document": """
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
    @Published private(set) var leftSelectAllSignal = UUID()
    @Published private(set) var rightSelectAllSignal = UUID()
    @Published private(set) var isDirty = false
    @Published var showDirectoryBrowser = false
    @Published var directoryBrowserSessions: [DirectoryBrowserRootSession] = []
    @Published var selectedDirectorySessionID: UUID?
    @Published private(set) var lastSaveMessage: String?
""",
    "mode": """
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
""",
    "translation": """
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
""",
    "assistant": """
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
    @Published private(set) var readingAssistantActiveTask: ReadingAssistantPanel?
    @Published var explanationSelectionText = ""
    @Published var explanationPanelSelectedText = ""
    @Published private(set) var explanationSelectAllSignal = UUID()
    @Published private(set) var isSpeakingExplanation = false
    @Published private(set) var isExplanationSpeechPaused = false
    @Published private(set) var currentSpeechSource: SpeechSource?
    private var readingPromptMessages: [ChatMessage] = [ReadingAssistantSession.defaultWelcomeMessage]
    private var speakingRefreshTask: Task<Void, Never>?
""",
    "evolution": """
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
    private var evolutionPromptMessages: [ChatMessage] = []
""",
}


def fix_file(path: Path, session: str) -> None:
    text = path.read_text(encoding="utf-8")
    # Insert property block after host line
    if "@Published var fileContent" not in text and session in PROP_BLOCKS:
        text = text.replace(
            "unowned var host: ReadingViewModel!\n\n",
            "unowned var host: ReadingViewModel!\n" + PROP_BLOCKS[session] + "\n",
            1,
        )
    # Remove duplicate private vars that are now in PROP_BLOCKS
    for dup in ("private var lastCommittedSelectionText", "private var currentFileURL"):
        if session == "document" and dup in PROP_BLOCKS["document"]:
            text = re.sub(rf"\s*{re.escape(dup)}[^\n]*\n", "\n", text, count=1)

    own = SESSION_PROPS.get(session, set())

    def repl_host(m: re.Match) -> str:
        name = m.group(1)
        if name in own:
            return m.group(0)
        if name in ("self", "host", "Task", "guard", "return", "let", "var", "if", "else"):
            return m.group(0)
        return f"host.{name}"

    for prop in HOST_PROPS:
        text = re.sub(rf"(?<![.\w]){prop}(?![.\w])", f"host.{prop}", text)
    text = text.replace("host.host.", "host.")

    # Cross-session bare refs (common)
    cross = {
        "readingPageTexts": "host.mode.readingPageTexts",
        "readingSourcePageRanges": "host.mode.readingSourcePageRanges",
        "readingSpreadIndex": "host.mode.readingSpreadIndex",
        "experienceMode": "host.mode.experienceMode",
        "lessonPlanContent": "host.translation.lessonPlanContent",
        "translationAlignment": "host.translation.translationAlignment",
        "readingChatInput": "host.assistant.readingChatInput",
        "readingPromptMessages": "host.assistant.readingPromptMessages",
        "chatMessages": "host.assistant.chatMessages",
        "readingAssistantPanel": "host.assistant.readingAssistantPanel",
        "optimizationQueue": "host.evolution.optimizationQueue",
        "evolutionChatInput": "host.evolution.evolutionChatInput",
        "evolutionPromptMessages": "host.evolution.evolutionPromptMessages",
        "evolutionRunKind": "host.evolution.evolutionRunKind",
        "executingEvolutionCommandNumber": "host.evolution.executingEvolutionCommandNumber",
        "evolutionSessionTokensConsumed": "host.evolution.evolutionSessionTokensConsumed",
        "evolutionAgentContextTokens": "host.evolution.evolutionAgentContextTokens",
        "showsExecutionTrace": "host.evolution.showsExecutionTrace",
        "isEvolutionRebuilding": "host.evolution.isEvolutionRebuilding",
        "selectedText": "host.document.selectedText",
        "fileContent": "host.document.fileContent",
        "fileName": "host.document.fileName",
        "lastCommittedSelectionText": "host.document.lastCommittedSelectionText",
        "lastCommittedSelectionRange": "host.document.lastCommittedSelectionRange",
        "selectedTextRange": "host.document.selectedTextRange",
        "lastCommittedLessonPlanSelectedText": "host.document.lastCommittedLessonPlanSelectedText",
        "lastCommittedExplanationPanelSelectedText": "host.document.lastCommittedExplanationPanelSelectedText",
        "lessonPlanSelectedText": "host.translation.lessonPlanSelectedText",
        "explanationPanelSelectedText": "host.assistant.explanationPanelSelectedText",
        "explanationSelectionText": "host.assistant.explanationSelectionText",
        "isSpeakingExplanation": "host.assistant.isSpeakingExplanation",
    }
    if session != "document":
        for k, v in cross.items():
            if k in own:
                continue
            text = re.sub(rf"(?<![.\w]){k}(?![.\w])", v, text)
    if session != "mode":
        for k in ("readingPageTexts", "readingSourcePageRanges", "readingSpreadIndex", "experienceMode"):
            if k not in own:
                text = re.sub(rf"(?<![.\w]){k}(?![.\w])", cross[k], text)

    text = text.replace("host.host.", "host.")
    text = text.replace("stopExplanationSpeech()", "host.assistant.stopExplanationSpeech()")
    text = text.replace("host.assistant.host.", "host.assistant.")
    path.write_text(text, encoding="utf-8")


def main() -> None:
    mapping = {
        "ReadingDocumentSession.swift": "document",
        "ReadingModeSession.swift": "mode",
        "ReadingTranslationSession.swift": "translation",
        "ReadingAssistantSession.swift": "assistant",
        "ReadingEvolutionSession.swift": "evolution",
    }
    for fname, sess in mapping.items():
        fix_file(READING / fname, sess)
        print("fixed", fname)


if __name__ == "__main__":
    main()

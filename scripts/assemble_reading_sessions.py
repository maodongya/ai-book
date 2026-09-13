#!/usr/bin/env python3
"""Assemble Phase B session Swift files from split parts + property rewrites."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
READING = ROOT / "Sources/AIBook/Reading"
PARTS = ROOT / "scripts" / "split_out"
ORIGINAL = READING / "ReadingViewModel.swift"

SESSION_META = {
    "document": (
        "ReadingDocumentSession.swift",
        "左页文档会话：打开/保存、选区、目录浏览与 readme 笔记状态。",
        [
            "fileContent", "fileName", "isDocumentOpen", "selectedText",
            "leftSelectAllSignal", "rightSelectAllSignal", "isDirty",
            "showDirectoryBrowser", "directoryBrowserSessions", "selectedDirectorySessionID",
            "lastSaveMessage",
        ],
    ),
    "mode": (
        "ReadingModeSession.swift",
        "阅读模式会话：学习/阅读体验切换、分页与 spread 索引持久化。",
        ["experienceMode", "readingPageTexts", "readingSourcePageRanges", "readingSpreadIndex"],
    ),
    "translation": (
        "ReadingTranslationSession.swift",
        "翻译会话：译文内容、对齐、表格滚动与翻译 API 调用链。",
        [
            "lessonPlanSelectedText", "lessonPlanContent", "translationAlignment",
            "translationTableViewEnabled", "translationTableScrollTargetID",
            "translationTableHighlightedBlockID", "translationTableFocusTranslationBlockID",
        ],
    ),
    "assistant": (
        "ReadingAssistantSession.swift",
        "读书助手会话：讲解/名著补充、对话消息、朗读与输入框。",
        [
            "chatMessages", "readingChatInput", "readingAssistantPanel",
            "readingAssistantActiveTask", "explanationSelectionText",
            "explanationPanelSelectedText", "explanationSelectAllSignal",
            "isSpeakingExplanation", "isExplanationSpeechPaused", "currentSpeechSource",
        ],
    ),
    "evolution": (
        "ReadingEvolutionSession.swift",
        "AI 进化会话：优化队列、分析/进化请求与 token 预算。",
        [
            "evolutionChatInput", "optimizationQueue", "evolutionRunKind",
            "evolutionLastRequestId", "executingEvolutionCommandNumber",
            "isEvolutionRebuilding", "evolutionRebuildStatus",
            "evolutionSessionTokensConsumed", "evolutionAgentContextTokens",
            "showsExecutionTrace",
        ],
    ),
}

# Properties that live on host ReadingViewModel (not rewritten to host.x in session bodies).
HOST_PROPS = {
    "rightPageTab", "isLoading", "isRunning", "streamingThinking", "streamingResponse",
    "streamingToolStatus", "streamingToolSteps", "errorMessage", "showSettings",
    "showBookSettings", "showUserManual", "activeTask", "llmService", "cursorService",
    "isRestoringSession", "suppressReplySpeech",
}

# Cross-session: in session bodies, rewrite bare identifier to host.otherSession.prop
CROSS_SESSION: dict[str, tuple[str, str]] = {
    # document -> others (filled at runtime by rewrite engine)
}


def extract_published_blocks(source: str, names: list[str]) -> str:
    lines: list[str] = []
    for name in names:
        pat = re.compile(
            rf"^(\s*@Published[^\n]*\n\s*(?:private\s*\(set\)\s*)?var {re.escape(name)}[^\n]*\n(?:\s*didSet\s*\{{[^}}]*\}}\s*)?)",
            re.MULTILINE | re.DOTALL,
        )
        m = pat.search(source)
        if not m:
            # try without didSet
            pat2 = re.compile(
                rf"^(\s*@Published[^\n]*\n\s*(?:private\s*\(set\)\s*)?var {re.escape(name)}[^\n]*\{{[^}}]*\}}\s*)",
                re.MULTILINE | re.DOTALL,
            )
            m = pat2.search(source)
        if m:
            lines.append(m.group(1).rstrip())
        else:
            print(f"WARN: missing property {name}")
    return "\n".join(lines) + "\n"


def extract_private_vars(source: str, session: str) -> str:
    mapping = {
        "document": [
            "lastCommittedSelectionText", "lastCommittedSelectionRange",
            "lastCommittedLessonPlanSelectedText", "lastCommittedExplanationPanelSelectedText",
            "currentFileURL", "savedContent", "selectedTextRange",
            "autoSaveTask", "saveMessageTask",
        ],
        "mode": ["pendingReadingSourcePage", "lastReadingPageContentSize", "readingPositionKeyPrefix", "readingSourcePageKeyPrefix"],
        "translation": ["isApplyingAlignment", "sourceTextScrollProxy", "translationTextScrollProxy", "translationScrollSync"],
        "assistant": [
            "readingPromptMessages", "speakingRefreshTask",
        ],
        "evolution": [
            "optimizationQueueStore", "autoEvolutionTask", "didScheduleAutoEvolution",
            "evolutionPromptMessages",
        ],
    }
    out: list[str] = []
    for name in mapping.get(session, []):
        pat = re.compile(rf"^(\s*(?:private|let|var)\s+.*{re.escape(name)}.*)$", re.MULTILINE)
        m = pat.search(source)
        if m:
            line = m.group(1)
            if line.strip().startswith("private let optimizationQueueStore"):
                line = "    let optimizationQueueStore = OptimizationQueueStore(\n        fileURL: OptimizationQueueStore.defaultFileURL\n    )"
            out.append(line)
    return "\n".join(out) + ("\n" if out else "")


def rewrite_body(body: str, session: str) -> str:
    # Self/session-owned identifiers — do not prefix with host.
    own: set[str] = set()
    for _, (_, _, props) in SESSION_META.items():
        own.update(props)
    own.update(
        {
            "lastCommittedSelectionText", "lastCommittedSelectionRange",
            "lastCommittedLessonPlanSelectedText", "lastCommittedExplanationPanelSelectedText",
            "currentFileURL", "savedContent", "selectedTextRange", "autoSaveTask", "saveMessageTask",
            "pendingReadingSourcePage", "lastReadingPageContentSize",
            "isApplyingAlignment", "sourceTextScrollProxy", "translationTextScrollProxy", "translationScrollSync",
            "readingPromptMessages", "speakingRefreshTask",
            "optimizationQueueStore", "autoEvolutionTask", "didScheduleAutoEvolution",
            "evolutionPromptMessages", "chatSessionStore", "readmeNotesStore",
        }
    )

    def host_path(name: str) -> str:
        if name in HOST_PROPS:
            return f"host.{name}"
        for key, (_, _, props) in SESSION_META.items():
            if name in props or name in {
                "displayFileName", "isEditingNotes", "canEnterReadingMode", "readingSpreadCount",
                "readingPageCount", "canAlignTranslationWithSource", "isTranslationAlignmentLocked",
                "translationAlignmentStatusText", "showsTranslationTableView", "canUseTranslationTableView",
                "shouldSyncTranslationScroll", "effectiveSelectedText", "effectiveLessonPlanSelectedText",
                "effectiveExplanationPanelSelectedText", "canReadAloud", "hasExplanationContent",
                "explanationDisplayMessages", "evolutionStatusLabel", "evolutionItems", "hasPendingOptimization",
                "isAnalyzing", "evolutionLiveToolLabel", "evolutionContextUsage", "evolutionTokenBudget",
                "canRunEvolution", "showsEvolutionExecutionTrace", "canSaveEvolutionCommands",
                "canOpenEvolutionCommands", "canClearReadingContext", "canClearAIContext",
                "cursorContextUsage", "llmContextUsage", "activePromptContext",
            }:
                if key == session:
                    return name
                return f"host.{key}.{name}" if name not in HOST_PROPS else f"host.{name}"
        return f"host.{name}"

    # Method calls on host
    body = re.sub(r"\bSelf\.untitledMarker\b", "ReadingViewModel.untitledMarker", body)
    body = re.sub(r"\bSelf\.defaultWelcomeMessage\b", "ReadingAssistantSession.defaultWelcomeMessage", body)
    body = re.sub(r"\bSelf\.defaultEvolutionWelcomeMessage\b", "ReadingEvolutionSession.defaultEvolutionWelcomeMessage", body)
    body = re.sub(r"\bEvolutionRunKind\b", "ReadingEvolutionRunKind", body)
    body = re.sub(r"\bPromptContext\b", "ReadingPromptContext", body)

    for meth in (
        "selectRightPageTab", "selectReadingAssistantPanel", "beginRun", "resetStreamingState",
        "sendMessage", "persistChatSession", "syncDisplayedChatMessages", "appendDisplayedMessage",
        "appendDisplayOnlyMessage", "appendPromptMessage", "updatePromptMessage", "removePromptMessage",
        "contextHistory", "apiHistory", "isDisplaying", "activePromptContext", "stopCurrentRun",
        "guardEvolutionTokenLimit", "recordEvolutionCursorEstimate", "recordEvolutionTokenUsage",
        "updateEvolutionAgentContextTokens", "clearEvolutionExecutionState", "fetchAssistantReply",
        "handleLLMStreamEvent", "handleCursorStreamEvent", "resolvedToolStepsForMessage",
        "revertRunningOptimization", "ensureEvolutionWelcome", "ensureEvolutionUsesCursor",
        "loadOptimizationQueue", "persistOptimizationQueue", "refreshTranslationAlignmentAfterSourceChange",
        "repairCollapsedParagraphAlignmentIfNeeded", "syncTranslationScrollPresentation",
        "rebuildTranslationAlignment", "alignTranslationWithSource", "loadLessonPlan", "loadExplanation",
        "loadFile", "showTransientSaveMessage", "openUserManual",
    ):
        body = re.sub(rf"\b{meth}\(", f"host.{meth}(", body)

    # host.host. fix
    body = body.replace("host.host.", "host.")

    return body


def build_session(session: str, source: str) -> str:
    fname, doc, props = SESSION_META[session]
    class_name = fname.replace(".swift", "")
    part = (PARTS / f"{session}.swift.part").read_text(encoding="utf-8")
    if session == "translation":
        part += (PARTS / "unknown.swift.part").read_text(encoding="utf-8")
    part = rewrite_body(part, session)
    published = extract_published_blocks(source, props)
    priv = extract_private_vars(source, session)

    imports = "import AIBookEvolution\nimport AppKit\nimport Foundation\n\n"
    header = f"@MainActor\n/// {doc}\nfinal class {class_name}: ObservableObject {{\n"
    host_line = "    unowned var host: ReadingViewModel!\n\n"
    footer = "}\n"

    computed = ""
    if session == "document":
        computed = """
    var displayFileName: String {
        guard isDocumentOpen || currentFileURL != nil || !fileContent.isEmpty else {
            return BookL10n.string("vm.noFileOpen")
        }
        let name = currentFileURL?.lastPathComponent ?? fileName
        return isDirty ? "\\(name) •" : name
    }

    var isEditingNotes: Bool {
        currentFileURL == nil
    }

"""
    elif session == "mode":
        computed = """
    var canEnterReadingMode: Bool {
        !host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var readingSpreadCount: Int {
        max(1, (readingPageTexts.count + 1) / 2)
    }

    var readingPageCount: Int {
        readingPageTexts.count
    }

"""
    elif session == "translation":
        computed = (PARTS / "translation_computed.swift.part").read_text(encoding="utf-8") if (PARTS / "translation_computed.swift.part").exists() else ""

    return imports + header + host_line + published + priv + computed + part + footer


def extract_types(source: str) -> str:
    evo = re.search(r"enum EvolutionRunKind \{[^}]+\}", source, re.DOTALL)
    prompt = re.search(r"private enum PromptContext \{[^}]+\}", source, re.DOTALL)
    evo_text = evo.group(0).replace("EvolutionRunKind", "ReadingEvolutionRunKind") if evo else ""
    prompt_text = prompt.group(0).replace("private enum PromptContext", "enum ReadingPromptContext") if prompt else ""
    return f"""import Foundation

{prompt_text}

{evo_text}
"""


def build_orchestrator() -> str:
    part = (PARTS / "orchestrator.swift.part").read_text(encoding="utf-8")
    part = rewrite_body(part, "orchestrator")
    return f"""import AIBookEvolution
import Foundation

@MainActor
/// 读书/进化共用的流式请求编排（由 ReadingViewModel 持有）。
final class ReadingMessageOrchestrator {{
    unowned var host: ReadingViewModel!

{part}
}}
"""


def build_vm(source: str) -> str:
    part = (PARTS / "vm.swift.part").read_text(encoding="utf-8")
    part = rewrite_body(part, "vm")
    statics = """
    static let untitledMarker = "未命名"

"""
    header = """import AIBookEvolution
import AppKit
import Foundation

@MainActor
/// 双页读书编排：左页原文、右页讲解/翻译/进化，以及 AI 与朗读请求的状态机。
final class ReadingViewModel: ObservableObject {
"""
    sessions = """
    let document = ReadingDocumentSession()
    let mode = ReadingModeSession()
    let translation = ReadingTranslationSession()
    let assistant = ReadingAssistantSession()
    let evolution = ReadingEvolutionSession()
    private let orchestrator = ReadingMessageOrchestrator()

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
    private let readmeNotesStore = ReadmeNotesStore.shared
    var isRestoringSession = false
    private var activeTask: Task<Void, Never>?
    private var suppressReplySpeech = false

"""
    init_body = """
    init() {
        document.host = self
        mode.host = self
        translation.host = self
        assistant.host = self
        evolution.host = self
        orchestrator.host = self
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
        for session in [document as ObservableObject, mode, translation, assistant, evolution] {
            session.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }.store(in: &cancellables)
        }
    }

    private var cancellables = Set<AnyCancellable>()

"""
    # Fix: need Combine import for cancellables - use manual forward instead

    return ""  # placeholder


def main() -> None:
    source = ORIGINAL.read_text(encoding="utf-8")
    types = extract_types(source)
    (READING / "ReadingViewModelTypes.swift").write_text(types, encoding="utf-8")
    for session in SESSION_META:
        text = build_session(session, source)
        (READING / SESSION_META[session][0]).write_text(text, encoding="utf-8")
        print("Wrote", SESSION_META[session][0], len(text.splitlines()))
    orch = build_orchestrator()
    (READING / "ReadingMessageOrchestrator.swift").write_text(orch, encoding="utf-8")
    print("Wrote orchestrator", len(orch.splitlines()))


if __name__ == "__main__":
    main()

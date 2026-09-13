#!/usr/bin/env python3
"""One-off helper: extract ReadingViewModel.swift into session files (Phase B)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "Sources/AIBook/Reading/ReadingViewModel.swift"

# Methods assigned to sessions (remainder stays in VM + orchestrator).
DOCUMENT_METHODS = {
    "confirmDiscardUnsavedIfNeeded",
    "newDocument",
    "openFile",
    "openDirectory",
    "addDirectoryFromPanel",
    "selectDirectorySession",
    "removeDirectorySession",
    "toggleDirectoryNodeExpanded",
    "dismissDirectoryBrowser",
    "openFileFromDirectory",
    "pickDirectoryURL",
    "addDirectorySession",
    "restoreDirectoryBrowserSessions",
    "persistDirectoryBrowserSessions",
    "loadDirectoryTree",
    "openDroppedFile",
    "loadFile",
    "save",
    "saveAs",
    "saveSelectionAs",
    "exportContent",
    "loadReadmeNotes",
    "saveReadmeNotes",
    "syncReadmeNotesIfNeeded",
    "writeContent",
    "updateSelection",
    "updateLessonPlanSelection",
    "updateExplanationPanelSelection",
    "selectAllLeftPage",
    "selectAllRightPage",
    "scheduleAutoSaveIfNotes",
    "showTransientSaveMessage",
    "syncLeftPageWithEvolutionCommands",
    "syncLeftPageFromOptimizationQueue",
    "syncOptimizationQueueFromLeftPageIfNeeded",
    "confirmReplaceOptimizationQueue",
    "assistantOutputFileName",
    "persistLeftPage",
    "applySupplementToLeftPage",
    "currentSelectionRange",
    "ranges",
    "isValidRange",
}

MODE_METHODS = {
    "readingPageText",
    "leftPageIndex",
    "rightPageIndex",
    "currentVisibleSourcePageIndex",
    "readingProgressLabel",
    "repaginateForReading",
    "applyReadingSpread",
    "restoreLearningScrollPositionFromReadingSpread",
    "fileContentRange",
    "enterReadingMode",
    "exitReadingMode",
    "toggleReadingMode",
    "canTurnReadingSpreadForward",
    "canTurnReadingSpreadBackward",
    "turnReadingSpreadForward",
    "turnReadingSpreadBackward",
    "readingPositionStorageKey",
    "readingSourcePageStorageKey",
    "restoreReadingSpreadIndex",
    "persistReadingSpreadIndex",
}

TRANSLATION_METHODS = {
    "sendChatInput",
    "generateLessonPlan",
    "refineLessonPlan",
    "clearLessonPlan",
    "saveLessonPlan",
    "openLessonPlanFile",
    "loadLessonPlan",
    "runLessonPlanTask",
    "applyTranslationResult",
    "alignTranslationWithSource",
    "rebuildTranslationAlignment",
    "refreshTranslationAlignmentAfterSourceChange",
    "repairCollapsedParagraphAlignmentIfNeeded",
    "handleSourceTextScroll",
    "handleTranslationTextScroll",
    "handleTranslationTableVisibleBlock",
    "lockTranslationAlignment",
    "unlockTranslationAlignment",
    "updateTranslationTableBlock",
    "splitTranslationTableBlock",
    "nextTranslationTableEntryIndex",
    "sourceSearchStart",
    "translationDisplayTitle",
    "syncTranslationScrollPresentation",
    "alignmentForScrollSync",
    "sourceRangeOffsetInFileContent",
    "refreshTranslationAlignmentStaleState",
    "sourceHashMatches",
    "lessonPlanSourceText",
    "existingTranslationForPrompt",
    "buildLessonPlanPrompt",
    "lessonPlanFileName",
}

ASSISTANT_METHODS = {
    "selectReadingAssistantPanel",
    "updateAssistantMessage",
    "canEditExplanationMessage",
    "deleteChatMessage",
    "saveAssistantMessage",
    "readAssistantMessage",
    "openAssistantMessageFile",
    "shouldDisplayInExplanationPanel",
    "explanationTranscriptText",
    "explanationSpeakableText",
    "newExplanationDocument",
    "clearExplanation",
    "saveExplanationDocument",
    "openExplanationDocument",
    "loadExplanation",
    "selectAllExplanation",
    "readExplanationAloud",
    "readOriginalFullTextAloud",
    "readOriginalSelectionAloud",
    "readTranslationFullTextAloud",
    "readTranslationSelectionAloud",
    "readExplanationFullTextAloud",
    "readExplanationSelectionAloud",
    "toggleReadAloudIfSpeaking",
    "isReadingWelcomeMessage",
    "isExplanationInstructionMessage",
    "explanationFileName",
    "syncExplanationSelectionText",
    "applyImportedExplanationText",
    "parseImportedExplanationMessages",
    "defaultImportedExplanationMessages",
    "explainSelection",
    "explainFullText",
    "readSelectionAloud",
    "readLessonPlanAloud",
    "supplementClassicLiterature",
    "speakExplanation",
    "toggleExplanationSpeechPause",
    "stopExplanationSpeech",
    "syncExplanationSpeechState",
    "scheduleSpeakingStatusRefresh",
    "buildChatPrompt",
    "surroundingContext",
    "isTranslationHistoryMessage",
    "appendDisplayOnlyMessage",
}

EVOLUTION_METHODS = {
    "loadOptimizationQueue",
    "persistOptimizationQueue",
    "evolutionTokenBudget",
    "ensureEvolutionUsesCursor",
    "guardEvolutionTokenLimit",
    "recordEvolutionTokenUsage",
    "updateEvolutionAgentContextTokens",
    "recordEvolutionCursorEstimate",
    "clearEvolutionExecutionState",
    "revertRunningOptimization",
    "saveEvolutionCommands",
    "openEvolutionCommands",
    "exportEvolutionCommands",
    "startEvolution",
    "analyzeOptimizations",
    "skipOptimization",
    "restoreOptimization",
    "deleteOptimization",
    "pinOptimization",
    "addUserOptimization",
    "scheduleAutoEvolutionIfNeeded",
    "handleEvolutionRebuild",
    "buildEvolutionChatPrompt",
    "sendEvolutionChatInput",
    "applyEvolutionQueueUpdate",
    "handleAnalysisCompletion",
    "gitWorkingTreeIsClean",
    "extractEvolutionCommandNumber",
    "isEvolutionWelcomeMessage",
    "ensureEvolutionWelcome",
}

ORCHESTRATOR_METHODS = {
    "resetStreamingState",
    "beginRun",
    "handleLLMStreamEvent",
    "handleCursorStreamEvent",
    "applyToolStepUpdate",
    "resolvedToolStepsForMessage",
    "sendMessage",
    "message",
    "fetchAssistantReply",
    "fetchCursorReply",
    "fetchLLMReply",
}

VM_METHODS = {
    "onAppear",
    "stopCurrentRun",
    "applyLanguageChange",
    "clearReadingContext",
    "clearAIContext",
    "selectRightPageTab",
    "openSettings",
    "openBookSettings",
    "openUserManual",
    "runningStatusText",
    "restoreChatSession",
    "persistChatSession",
    "apiHistory",
    "contextHistory",
    "appendPromptMessage",
    "updatePromptMessage",
    "removePromptMessage",
    "appendDisplayedMessage",
    "syncDisplayedChatMessages",
    "isDisplaying",
}


def main() -> None:
    text = SRC.read_text(encoding="utf-8")
    func_re = re.compile(
        r"^(\s*(?:@\w+\s*)*(?:private\s+|fileprivate\s+)?func\s+(\w+))",
        re.MULTILINE,
    )
    matches = list(func_re.finditer(text))
    buckets: dict[str, list[str]] = {k: [] for k in ["document", "mode", "translation", "assistant", "evolution", "orchestrator", "vm", "unknown"]}
    for i, m in enumerate(matches):
        name = m.group(2)
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        chunk = text[start:end].rstrip() + "\n"
        assigned = "unknown"
        if name in DOCUMENT_METHODS:
            assigned = "document"
        elif name in MODE_METHODS:
            assigned = "mode"
        elif name in TRANSLATION_METHODS:
            assigned = "translation"
        elif name in ASSISTANT_METHODS:
            assigned = "assistant"
        elif name in EVOLUTION_METHODS:
            assigned = "evolution"
        elif name in ORCHESTRATOR_METHODS:
            assigned = "orchestrator"
        elif name in VM_METHODS:
            assigned = "vm"
        buckets[assigned].append(chunk)

    out_dir = ROOT / "scripts" / "split_out"
    out_dir.mkdir(exist_ok=True)
    for bucket, chunks in buckets.items():
        (out_dir / f"{bucket}.swift.part").write_text("\n".join(chunks), encoding="utf-8")
    print("Wrote parts to", out_dir)
    for k, v in buckets.items():
        print(k, len(v), "funcs")


if __name__ == "__main__":
    main()

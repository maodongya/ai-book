#!/usr/bin/env python3
"""Rewrite viewModel.foo to viewModel.<session>.foo for Phase B session split."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "Sources"

SESSION_PROPS: dict[str, str] = {}
for name in (
    "fileContent",
    "fileName",
    "isDocumentOpen",
    "selectedText",
    "isDirty",
    "displayFileName",
    "showDirectoryBrowser",
    "directoryBrowserSessions",
    "selectedDirectorySessionID",
    "leftSelectAllSignal",
    "rightSelectAllSignal",
    "lastSaveMessage",
    "isEditingNotes",
):
    SESSION_PROPS[name] = "document"

for name in (
    "experienceMode",
    "readingSpreadIndex",
    "readingPageTexts",
    "readingPageCount",
    "readingSpreadCount",
    "canEnterReadingMode",
):
    SESSION_PROPS[name] = "mode"

for name in (
    "lessonPlanContent",
    "lessonPlanSelectedText",
    "translationAlignment",
    "translationTableViewEnabled",
    "translationTableScrollTargetID",
    "translationTableHighlightedBlockID",
    "translationTableFocusTranslationBlockID",
    "showsTranslationTableView",
    "canAlignTranslationWithSource",
    "isTranslationAlignmentLocked",
    "translationAlignmentStatusText",
    "canUseTranslationTableView",
    "sourceTextScrollProxy",
    "translationTextScrollProxy",
):
    SESSION_PROPS[name] = "translation"

for name in (
    "chatMessages",
    "readingChatInput",
    "readingAssistantPanel",
    "readingAssistantActiveTask",
    "explanationSelectionText",
    "explanationPanelSelectedText",
    "explanationSelectAllSignal",
    "isSpeakingExplanation",
    "isExplanationSpeechPaused",
    "currentSpeechSource",
    "explanationDisplayMessages",
    "hasExplanationContent",
    "effectiveSelectedText",
    "effectiveLessonPlanSelectedText",
    "effectiveExplanationPanelSelectedText",
):
    SESSION_PROPS[name] = "assistant"

for name in (
    "optimizationQueue",
    "evolutionChatInput",
    "executingEvolutionCommandNumber",
    "isEvolutionRebuilding",
    "evolutionRebuildStatus",
    "evolutionSessionTokensConsumed",
    "evolutionAgentContextTokens",
    "evolutionRunKind",
    "evolutionLastRequestId",
    "showsExecutionTrace",
    "evolutionItems",
    "hasPendingOptimization",
    "isAnalyzing",
    "evolutionStatusLabel",
):
    SESSION_PROPS[name] = "evolution"

SESSION_METHODS: dict[str, str] = {}
for name, session in [
    ("newDocument", "document"),
    ("openFile", "document"),
    ("save", "document"),
    ("saveAs", "document"),
    ("saveSelectionAs", "document"),
    ("updateSelection", "document"),
    ("selectAllLeftPage", "document"),
    ("openDirectory", "document"),
    ("addDirectoryFromPanel", "document"),
    ("selectDirectorySession", "document"),
    ("removeDirectorySession", "document"),
    ("toggleDirectoryNodeExpanded", "document"),
    ("dismissDirectoryBrowser", "document"),
    ("openFileFromDirectory", "document"),
    ("openDroppedFile", "document"),
    ("confirmDiscardUnsavedIfNeeded", "document"),
    ("loadFile", "document"),
    ("readingPageText", "mode"),
    ("leftPageIndex", "mode"),
    ("rightPageIndex", "mode"),
    ("currentVisibleSourcePageIndex", "mode"),
    ("readingProgressLabel", "mode"),
    ("repaginateForReading", "mode"),
    ("enterReadingMode", "mode"),
    ("exitReadingMode", "mode"),
    ("toggleReadingMode", "mode"),
    ("canTurnReadingSpreadForward", "mode"),
    ("canTurnReadingSpreadBackward", "mode"),
    ("turnReadingSpreadForward", "mode"),
    ("turnReadingSpreadBackward", "mode"),
    ("alignTranslationWithSource", "translation"),
    ("handleTranslationTextScroll", "translation"),
    ("handleTranslationTableVisibleBlock", "translation"),
    ("updateTranslationTableBlock", "translation"),
    ("selectAllRightPage", "translation"),
    ("readLessonPlanAloud", "assistant"),
    ("clearLessonPlan", "translation"),
    ("saveLessonPlan", "translation"),
    ("openLessonPlanFile", "translation"),
    ("translateSelection", "translation"),
    ("translateFullText", "translation"),
    ("explainSelection", "assistant"),
    ("explainFullText", "assistant"),
    ("readSelectionAloud", "assistant"),
    ("supplementClassicLiterature", "assistant"),
    ("selectReadingAssistantPanel", "assistant"),
    ("saveAssistantMessage", "assistant"),
    ("readAssistantMessage", "assistant"),
    ("deleteChatMessage", "assistant"),
    ("updateAssistantMessage", "assistant"),
    ("newExplanationDocument", "assistant"),
    ("clearExplanation", "assistant"),
    ("saveExplanationDocument", "assistant"),
    ("openExplanationDocument", "assistant"),
    ("selectAllExplanation", "assistant"),
    ("readExplanationAloud", "assistant"),
    ("readOriginalFullTextAloud", "assistant"),
    ("readOriginalSelectionAloud", "assistant"),
    ("readTranslationFullTextAloud", "assistant"),
    ("readTranslationSelectionAloud", "assistant"),
    ("readExplanationFullTextAloud", "assistant"),
    ("readExplanationSelectionAloud", "assistant"),
    ("toggleExplanationSpeechPause", "assistant"),
    ("stopExplanationSpeech", "assistant"),
    ("updateExplanationPanelSelection", "assistant"),
    ("updateLessonPlanSelection", "assistant"),
    ("canEditExplanationMessage", "assistant"),
    ("startEvolution", "evolution"),
    ("analyzeOptimizations", "evolution"),
    ("skipOptimization", "evolution"),
    ("restoreOptimization", "evolution"),
    ("deleteOptimization", "evolution"),
    ("pinOptimization", "evolution"),
    ("addUserOptimization", "evolution"),
    ("saveEvolutionCommands", "evolution"),
    ("openEvolutionCommands", "evolution"),
    ("persistOptimizationQueue", "evolution"),
    ("loadOptimizationQueue", "evolution"),
    ("ensureEvolutionWelcome", "evolution"),
    ("evolutionTokenBudget", "evolution"),
]:
    SESSION_METHODS[name] = session


def patch(text: str) -> str:
    # Avoid double-rewriting viewModel.document.fileContent
    for prop, session in sorted(SESSION_PROPS.items(), key=lambda x: -len(x[0])):
        text = re.sub(
            rf"(?<!\.)viewModel\.{re.escape(prop)}\b(?!\.)",
            f"viewModel.{session}.{prop}",
            text,
        )
        text = re.sub(
            rf"\$viewModel\.{re.escape(prop)}\b",
            f"$viewModel.{session}.{prop}",
            text,
        )
    for method, session in sorted(SESSION_METHODS.items(), key=lambda x: -len(x[0])):
        text = re.sub(
            rf"viewModel\.{re.escape(method)}\(",
            f"viewModel.{session}.{method}(",
            text,
        )
    return text


def main() -> None:
    for path in ROOT.rglob("*.swift"):
        if path.name.startswith("ReadingViewModel") and "monolith" in path.name:
            continue
        original = path.read_text(encoding="utf-8")
        updated = patch(original)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            print("updated", path.relative_to(ROOT.parent))


if __name__ == "__main__":
    main()

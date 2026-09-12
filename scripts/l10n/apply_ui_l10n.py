#!/usr/bin/env python3
"""Apply BookL10n to ContentView, ExplanationChatView, BookInterface, etc."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "Sources/AIBook"

REPLACEMENTS: list[tuple[str, str]] = [
    ('.help("读书大模型（book 设置）")', '.help(BookL10n.string("help.bookLLMSettings"))'),
    ('.help("AI 进化 Cursor 模型")', '.help(BookL10n.string("help.evolutionCursorModel"))'),
    ('.help("有未保存的修改")', '.help(BookL10n.string("help.unsavedChanges"))'),
    ('?? "配置读书助手大模型（推荐本机 Ollama）"', '?? BookL10n.string("help.configureBookLLM")'),
    ('?? (viewModel.evolutionStatusLabel ?? "进化、保存/打开命令、清空上下文与设置")', '?? (viewModel.evolutionStatusLabel ?? BookL10n.string("help.evolutionDefault"))'),
    ('.help("切换到读书助手：讲解、朗读与文章翻译")', '.help(BookL10n.string("help.switchReadingAssistant"))'),
    ('.help("进入全屏阅读：左右双页翻页 · \\(BookKeyboardShortcuts.readingModeHint)")', '.help(BookL10n.format("help.enterReadingMode", BookKeyboardShortcuts.readingModeHint))'),
    ('.help(requiresBookLLM ? bookLLMToolbarHelp : "新建、打开、保存、另存为、全选与名著补充 · \\(BookKeyboardShortcuts.documentMenuSummary)")', '.help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.format("help.documentMenu", BookKeyboardShortcuts.documentMenuSummary))'),
    ('BookToolbarOverflowMenu(help: "原文、讲解、翻译与朗读等操作")', 'BookToolbarOverflowMenu(help: BookL10n.string("help.toolbarDocOverflow"))'),
    ('.help(requiresBookLLM ? bookLLMToolbarHelp : "选择/全文讲解、文稿管理与朗读 · \\(BookKeyboardShortcuts.explanationMenuSummary)")', '.help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.format("help.explanationMenu", BookKeyboardShortcuts.explanationMenuSummary))'),
    ('Text(viewModel.isSpeakingExplanation ? "停止朗读" : "朗读讲解")', 'Text(viewModel.isSpeakingExplanation ? BookL10n.string("action.readExplanationStop") : BookL10n.string("action.readExplanation"))'),
    ('.help(requiresBookLLM ? bookLLMToolbarHelp : "逐字/整段翻译、朗读与翻译文件管理 · \\(BookKeyboardShortcuts.translationMenuSummary)")', '.help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.format("help.translationMenu", BookKeyboardShortcuts.translationMenuSummary))'),
    ('Text(viewModel.isSpeakingExplanation ? "停止朗读" : "朗读翻译")', 'Text(viewModel.isSpeakingExplanation ? BookL10n.string("action.readExplanationStop") : BookL10n.string("action.readTranslation"))'),
    ('.help("原文、翻译与讲解的选中/全文朗读；朗读中请使用顶栏中部播控 · \\(BookKeyboardShortcuts.speechMenuSummary)")', '.help(BookL10n.format("help.speechMenu", BookKeyboardShortcuts.speechMenuSummary))'),
    ('BookToolbarOverflowMenu(help: "讲解/翻译分栏与一键操作")', 'BookToolbarOverflowMenu(help: BookL10n.string("help.panelOverflow"))'),
    ('.help(requiresEvolutionBackend ? evolutionToolbarHelp : "执行下一条优化队列（\\(BookKeyboardShortcuts.evolutionHint)）")', '.help(requiresEvolutionBackend ? evolutionToolbarHelp : BookL10n.format("help.runNextEvolution", BookKeyboardShortcuts.evolutionHint))'),
    ('BookToolbarOverflowMenu(help: "进化、分析与停止")', 'BookToolbarOverflowMenu(help: BookL10n.string("help.evolutionOverflow"))'),
    ('.help("当前朗读：\\(source.label)")', '.help(BookL10n.format("help.currentSpeech", source.label))'),
    ('.help("正在朗读")', '.help(BookL10n.string("help.speakingNow"))'),
    ('title: viewModel.isExplanationSpeechPaused ? "继续" : "暂停"', 'title: viewModel.isExplanationSpeechPaused ? BookL10n.string("action.resume") : BookL10n.string("action.pause")'),
    ('.help(viewModel.isExplanationSpeechPaused ? "继续朗读" : "暂停朗读")', '.help(viewModel.isExplanationSpeechPaused ? BookL10n.string("help.resumeSpeech") : BookL10n.string("help.pauseSpeech"))'),
    ('.help("停止朗读")', '.help(BookL10n.string("help.stopSpeech"))'),
    ('BookToolbarOverflowMenu(help: "朗读播控")', 'BookToolbarOverflowMenu(help: BookL10n.string("help.speechControls"))'),
    ('BookToolbarMenuCaption(title: "当前朗读：\\(source.label)")', 'BookToolbarMenuCaption(title: BookL10n.format("help.currentSpeech", source.label))'),
    ('Text(viewModel.isExplanationSpeechPaused ? "继续朗读" : "暂停朗读")', 'Text(viewModel.isExplanationSpeechPaused ? BookL10n.string("help.resumeSpeech") : BookL10n.string("help.pauseSpeech"))'),
    ('.help(requiresBookLLM ? bookLLMToolbarHelp : "讲解左页选中文字（\\(BookKeyboardShortcuts.explainSelectionHint)）")', '.help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.format("help.explainSelection", BookKeyboardShortcuts.explainSelectionHint))'),
    ('.help(requiresBookLLM ? bookLLMToolbarHelp : "讲解左页全文（\\(BookKeyboardShortcuts.explainFullTextHint)）")', '.help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.format("help.explainFull", BookKeyboardShortcuts.explainFullTextHint))'),
    ('.help(requiresBookLLM ? bookLLMToolbarHelp : "按左页原文生成逐字翻译，输出带对齐结构的 JSON")', '.help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.string("help.wordTranslationJSON"))'),
    ('.help(requiresBookLLM ? bookLLMToolbarHelp : "按左页原文生成整段翻译，输出按段落对齐的 JSON")', '.help(requiresBookLLM ? bookLLMToolbarHelp : BookL10n.string("help.paragraphTranslationJSON"))'),
    ('.help(requiresEvolutionBackend ? evolutionToolbarHelp : "AI 分析源码并写入优化队列")', '.help(requiresEvolutionBackend ? evolutionToolbarHelp : BookL10n.string("help.analyzeSource"))'),
    ('.help("停止当前进化或分析任务")', '.help(BookL10n.string("help.stopEvolutionTask"))'),
    ('.help("切换到 AI 进化：分析优化队列并升级 ai-book")', '.help(BookL10n.string("help.switchEvolution"))'),
    (': (viewModel.evolutionStatusLabel ?? "进化、保存/打开命令、清空上下文与设置 · \\(BookKeyboardShortcuts.evolutionMenuSummary)")', ': (viewModel.evolutionStatusLabel ?? BookL10n.format("help.evolutionDefaultMenu", BookKeyboardShortcuts.evolutionMenuSummary))'),
    ('.help("恢复左右双页布局")', '.help(BookL10n.string("help.restoreSpread"))'),
    ('.help("全选左页文本")', '.help(BookL10n.string("help.selectAllLeftPage"))'),
    ('.help(isFocused ? "恢复双页" : side == .leading ? "原文占满桌面" : "右页占满桌面")', '.help(isFocused ? BookL10n.string("help.restoreSpreadFromFocus") : side == .leading ? BookL10n.string("help.leftFullscreen") : BookL10n.string("help.rightFullscreen"))'),
    ('return viewModel.isDirty ? "保存中…" : "已自动保存"', 'return viewModel.isDirty ? BookL10n.string("status.saving") : BookL10n.string("status.autosaved")'),
    ('.help("显示输入")', '.help(BookL10n.string("help.showInput"))'),
    ('Picker("右页分栏", selection:', 'Picker(BookL10n.string("picker.rightPanel"), selection:'),
    ('.help("专注阅读")', '.help(BookL10n.string("help.focusReading"))'),
    ('.help("显示工具栏")', '.help(BookL10n.string("help.showToolbar"))'),
    ('title: viewModel.isExplanationSpeechPaused ? "继续" : "暂停"', 'title: viewModel.isExplanationSpeechPaused ? BookL10n.string("action.resume") : BookL10n.string("action.pause")'),
    ('title: viewModel.isSpeakingExplanation ? "停止" : "朗读"', 'title: viewModel.isSpeakingExplanation ? BookL10n.string("action.stop") : BookL10n.string("action.readAloud")'),
    ('.help("对齐已失效，点击「对齐原文」恢复")', '.help(BookL10n.string("help.alignStale"))'),
    ('.help("右键可编辑、保存、朗读、复制或删除此条 AI 输出")', '.help(BookL10n.string("help.aiMessageContext"))'),
    ('.help("右键可复制或删除此条消息")', '.help(BookL10n.string("help.chatMessageContext"))'),
    ('Label(viewModel.isSpeakingExplanation ? "停止朗读" : "朗读此条"', 'Label(viewModel.isSpeakingExplanation ? BookL10n.string("action.readExplanationStop") : BookL10n.string("action.speechThisMessage")'),
    ('Text(viewModel.rightPageTab == .aiEvolution ? "AI 进化执行中…" : "Cursor 正在执行…")', 'Text(viewModel.rightPageTab == .aiEvolution ? BookL10n.string("vm.evolutionRunning") : BookL10n.string("evolution.cursorExecuting"))'),
    ('static let leftPageMark = "— 左页 —"', 'static let leftPageMark = BookL10n.string("ui.pageMark.left")'),
    ('static let rightPageMark = "— 右页 —"', 'static let rightPageMark = BookL10n.string("ui.pageMark.right")'),
    ('Text("在此输入命令笔记，或从顶栏「文件操作」新建 / 打开")', 'Text(BookL10n.string("welcome.notesHint"))'),
    ('Text("选中文字后点击「选择讲解」，或使用「全文讲解」")', 'Text(BookL10n.string("welcome.explainHint"))'),
    ('Label("打开文本文件", systemImage: "folder")', 'Label(BookL10n.string("welcome.openTextFile"), systemImage: "folder")'),
    ('return "讲解对话与翻译内容分栏展示"', 'return BookL10n.string("tab.readingAssistant.subtitle")'),
    ('return "Cursor Agent 风格 · 思考过程与工具步骤追踪"', 'return BookL10n.string("tab.aiEvolution.subtitle")'),
    ('.help("返回学习模式：讲解、翻译与 AI 助手")', '.help(BookL10n.string("help.readingSpreadBack"))'),
    ('.help(mode == .spread ? "左右双页翻页" : "单页占满屏幕")', '.help(mode == .spread ? BookL10n.string("help.readingSpreadLayout") : BookL10n.string("help.readingSinglePage"))'),
    ('pageCaption == "译文" && text == "本页暂无译文"', 'pageCaption == BookL10n.string("page.translationCaption") && text == BookL10n.string("page.noTranslationOnPage")'),
    ('return "第 \\(page) 页 / 共 \\(total) 页"', 'return BookL10n.format("vm.page.single", page, total)'),
    ('.help("打开 AIBook 功能说明书")', '.help(BookL10n.string("help.openManual"))'),
    ('labeledField("Cursor 模型", text:', 'labeledField(BookL10n.string("settings.cursorModel"), text:'),
    ('labeledField("Bridge 目录（可选）", text:', 'labeledField(BookL10n.string("settings.bridgeDir"), text:'),
    ('Toggle("自动升级", isOn:', 'Toggle(BookL10n.string("settings.autoUpgrade"), isOn:'),
]

FILES = [
    SRC / "Reading/ContentView.swift",
    SRC / "Reading/ExplanationChatView.swift",
    SRC / "UI/BookInterface.swift",
    SRC / "Core/RightPageTab.swift",
    SRC / "Reading/ReadingSpreadView.swift",
    SRC / "UI/SettingsView.swift",
]


def main() -> None:
    changed = 0
    for path in FILES:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        original = text
        for old, new in REPLACEMENTS:
            text = text.replace(old, new)
        if text != original:
            path.write_text(text, encoding="utf-8")
            changed += 1
            print(f"updated {path.relative_to(ROOT)}")
    print(f"Done. {changed} files changed.")


if __name__ == "__main__":
    main()

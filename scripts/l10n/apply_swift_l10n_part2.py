#!/usr/bin/env python3
"""Second pass: remaining UI literals → BookL10n."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "Sources/AIBook"

REPLACEMENTS: list[tuple[str, str]] = [
    ('Text("已记住 \\(sessions.count) 个目录，可继续添加并在其间切换")', 'Text(BookL10n.format("directory.summary", sessions.count))'),
    ('.help("关闭")', '.help(BookL10n.string("directory.help.close"))'),
    ('.help("添加目录")', '.help(BookL10n.string("directory.help.add"))'),
    ('.help("从列表移除")', '.help(BookL10n.string("directory.help.remove"))'),
    ('Text("暂无目录\\n点击 + 添加")', 'Text(BookL10n.string("directory.emptyList"))'),
    ('Button("打开") {', 'Button(BookL10n.string("action.open")) {'),
    ('headerCell("原文", width: layout.source)', 'headerCell(BookL10n.string("translation.header.source"), width: layout.source)'),
    ('headerCell("译文", width: layout.translation)', 'headerCell(BookL10n.string("translation.header.translation"), width: layout.translation)'),
    ('headerCell("说明", width: layout.note)', 'headerCell(BookL10n.string("translation.header.note"), width: layout.note)'),
    ('if source == "难点词语" { return "难点词语" }', 'if source == BookL10n.string("translation.row.difficult") { return BookL10n.string("translation.row.difficult") }'),
    ('return "一句话总译"', 'return BookL10n.string("translation.row.summary")'),
    ('ornamentToggle("书脊丝带",', 'ornamentToggle(BookL10n.string("style.ribbon"),'),
    ('ornamentToggle("折页角",', 'ornamentToggle(BookL10n.string("style.cornerFold"),'),
    ('ornamentToggle("纸纹",', 'ornamentToggle(BookL10n.string("style.paperTexture"),'),
    ('ornamentToggle("页眉饰线",', 'ornamentToggle(BookL10n.string("style.headerOrnament"),'),
    ('Text("作用于左页原文、右页讲解/翻译，以及阅读模式分页。")', 'Text(BookL10n.string("label.readingTypographyHint"))'),
    ('Picker("字体", selection:', 'Picker(BookL10n.string("label.font"), selection:'),
    ('Picker("字号", selection:', 'Picker(BookL10n.string("label.fontSize"), selection:'),
    ('Picker("Cursor 模型", selection:', 'Picker(BookL10n.string("cursor.modelPicker"), selection:'),
    ('.help("Cursor 已就绪")', '.help(BookL10n.string("cursor.ready"))'),
    ('.help("请在「进化设置」配置 Cursor API Key")', '.help(BookL10n.string("cursor.evolutionKeyHelp"))'),
    ('Text("在下方输入分析方向（可选），点「分析优化」让 AI 找出可改进处")', 'Text(BookL10n.string("composer.analyzeHint"))'),
    ('TextField("手写一条优化…", text: $draftTitle)', 'TextField(BookL10n.string("evolution.draft.placeholder"), text: $draftTitle)'),
    ('Text(item.source == .ai ? "AI" : "手写")', 'Text(item.source == .ai ? BookL10n.string("evolution.source.ai") : BookL10n.string("evolution.source.manual"))'),
    ('Button(showsDetail ? "收起详情" : "展开详情")', 'Button(showsDetail ? BookL10n.string("evolution.detail.collapse") : BookL10n.string("evolution.detail.expand"))'),
    ('Text("cursor-bridge 与 API Key 已就绪，可使用 Cursor 本地对话")', 'Text(BookL10n.string("cursor.readyBridge"))'),
    ('Text("请填写 Cursor API Key，进化功能仅支持 Cursor 本地桥接。")', 'Text(BookL10n.string("cursor.needKey"))'),
    ('Button("从环境变量读取")', 'Button(BookL10n.string("action.loadFromEnv"))'),
    ('Text("本地桥接通常无需 Key；若需云端能力，可在 Dashboard → Integrations 获取，或写入 ai-book/cursor.local.env。")', 'Text(BookL10n.string("cursor.keyHint"))'),
    ('Text("请在设置中同时配置多家 API Key，或在此选择提供商并保存。")', 'Text(BookL10n.string("llm.configureHint"))'),
    ('Text("API Key 可选：本地服务通常无需填写；启用 OLLAMA_API_KEY 或远程实例时再填。")', 'Text(BookL10n.string("llm.apiKeyOptionalHint"))'),
    ('Button(settings.provider == .ollama ? "保存配置" : "保存 API Key")', 'Button(settings.provider == .ollama ? BookL10n.string("llm.saveConfig") : BookL10n.string("llm.saveAPIKey"))'),
    ('Label(isTesting ? "测试中…" : "测试连接",', 'Label(isTesting ? BookL10n.string("llm.testing") : BookL10n.string("llm.testConnection"),'),
    ('Text("支持 \\(LLMConnector.supportedSummary)。设置页可同时配置多家 API，切换提供商不会丢失其他 Key。")', 'Text(BookL10n.format("llm.supportedSummary", LLMConnector.supportedSummary))'),
    ('Picker("当前提供商", selection:', 'Picker(BookL10n.string("llm.activeProvider"), selection:'),
    ('Picker("提供商", selection:', 'Picker(BookL10n.string("label.provider"), selection:'),
    ('Picker("模型", selection:', 'Picker(BookL10n.string("label.model"), selection:'),
    ('profileField("API 地址", text:', 'profileField(BookL10n.string("llm.apiAddress"), text:'),
    ('profileField("模型名称", text:', 'profileField(BookL10n.string("qwen.modelName"), text:'),
    ('profileField("API 地址（Base URL）", text:', 'profileField(BookL10n.string("llm.apiAddressBase"), text:'),
    ('TextField("或手动输入模型 ID", text:', 'TextField(BookL10n.string("llm.manualModelID"), text:'),
    ('Button("从环境变量 / dashscope.local.env 读取 Key")', 'Button(BookL10n.string("qwen.loadKeyFromEnv"))'),
    ('Text("接口：POST {Base URL}/chat/completions · Authorization: Bearer {API Key}")', 'Text(BookL10n.string("qwen.apiDoc"))'),
    ('Link("打开百炼控制台 API 页",', 'Link(BookL10n.string("qwen.consoleLink"),'),
    ('profileField("API 地址（OpenAI 兼容）", text:', 'profileField(BookL10n.string("ollama.openAICompat"), text:'),
    ('Label(catalog.isLoading ? "扫描中…" : "刷新模型",', 'Label(catalog.isLoading ? BookL10n.string("ollama.scanning") : BookL10n.string("action.refreshModels"),'),
    ('TextField("模型名称（可手动输入）", text:', 'TextField(BookL10n.string("ollama.modelNameField"), text:'),
    ('Picker("本地模型", selection:', 'Picker(BookL10n.string("ollama.localModels"), selection:'),
    ('Toggle("手动输入模型名", isOn:', 'Toggle(BookL10n.string("ollama.manualModel"), isOn:'),
    ('Text("本地 ollama serve 通常无需 Key；支持 OLLAMA_HOST / OLLAMA_API_KEY 环境变量与 ollama.local.env。保存后点击「刷新模型」可扫描本机已 pull 的模型。")', 'Text(BookL10n.string("ollama.localHint"))'),
    ('.help("隐藏输入")', '.help(BookL10n.string("composer.hideInput"))'),
    ('.help("重新扫描本机 Ollama 已安装模型")', '.help(BookL10n.string("composer.rescanOllama"))'),
    ('Section("已配置")', 'Section(BookL10n.string("llm.section.configured"))'),
    ('Section("未配置")', 'Section(BookL10n.string("llm.section.unconfigured"))'),
    ('Label("使用 macOS 系统语音朗读，无需下载或联网。"', 'Label(BookL10n.string("speech.systemVoiceHint")'),
    ('settingsCard(title: "朗读节奏", icon:', 'settingsCard(title: BookL10n.string("speech.pace"), icon:'),
    ('Picker("朗读节奏", selection:', 'Picker(BookL10n.string("speech.pace"), selection:'),
    ('settingsCard(title: "语言处理", icon:', 'settingsCard(title: BookL10n.string("speech.languageProcessing"), icon:'),
    ('Picker("语言处理", selection:', 'Picker(BookL10n.string("speech.languageProcessing"), selection:'),
    ('settingsCard(title: "讲解声音", icon:', 'settingsCard(title: BookL10n.string("speech.voice"), icon:'),
    ('Picker("讲解声音", selection:', 'Picker(BookL10n.string("speech.voice"), selection:'),
    ('TextField(settings.provider == .ollama ? "可选 API Key" : "sk-...",', 'TextField(settings.provider == .ollama ? BookL10n.string("llm.optionalAPIKey") : "sk-...",'),
    ('SecureField(settings.provider == .ollama ? "可选 API Key" : "sk-...",', 'SecureField(settings.provider == .ollama ? BookL10n.string("llm.optionalAPIKey") : "sk-...",'),
    ('Text(viewModel.isExplanationSpeechPaused ? "朗读已暂停" : "正在朗读讲解…")', 'Text(viewModel.isExplanationSpeechPaused ? BookL10n.string("speech.paused") : BookL10n.string("speech.speakingExplanation"))'),
    ('if settings.isCursorRunnable { return "已就绪" }', 'if settings.isCursorRunnable { return BookL10n.string("cursor.ready") }'),
    ('if settings.isCursorBridgeReady { return "需 API Key" }', 'if settings.isCursorBridgeReady { return BookL10n.string("cursor.needKeyShort") }'),
    ('return "桥接未就绪"', 'return BookL10n.string("cursor.bridgeNotReady")'),
    ('return text.isEmpty ? "大模型生成中…" : text', 'return text.isEmpty ? BookL10n.string("llm.generating") : text'),
    ('return "输入翻译要求，例如：整段白话翻译、保留关键词、减少注释"', 'return BookL10n.string("placeholder.translationShort")'),
    ('return "输入分析方向（可选），例如：读书助手讲解可见性、翻译入口；留空则全面分析。也可输入进化追问"', 'return BookL10n.string("placeholder.evolution")'),
]

FILES = list(SRC.rglob("*.swift"))


def main() -> None:
    changed = 0
    for path in FILES:
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

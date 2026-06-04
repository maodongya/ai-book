# AIBook — 辅助读书软件

Swift 实现的 macOS 辅助读书应用：左侧显示本地 `.txt` 原文，右侧由大模型讲解与选中文字相关的内容。

## 功能

- 打开本地 `.txt` 文本文件（⌘O 或工具栏）
- 左右分栏：左原文、右讲解
- 选中左侧文字后，点击「讲解选中内容」获取 AI 解读
- 支持 OpenAI 兼容接口：OpenAI、DeepSeek、Ollama、自定义端点

## 安装到「应用程序」

```bash
cd ai-book
./scripts/build-and-install.sh
```

安装后可在启动台或 `/Applications/AIBook.app` 打开。应用包含书籍风格图标与 Cursor 桥接模块。

左页默认加载 `readme.txt` 命令笔记，按 **⌘S** 保存到 `~/Library/Application Support/AIBook/readme-notes.txt`。

## 运行（开发）

```bash
cd ai-book
swift run
```

发布构建：

```bash
swift build -c release
.build/release/AIBook
```

## 右页解析方式

右页支持两种模式，在顶栏右侧 **AI 进化** 区切换「大模型 API」/「Cursor 本地」（与进化/追问共用同一设置，顶栏胶囊显示当前模式）：

| 模式 | 说明 |
|------|------|
| 大模型 API | OpenAI 兼容接口（OpenAI / DeepSeek / Ollama 等） |
| Cursor 本地 | 调用本机 Cursor Agent 进行内容解析与对话 |

### Cursor 本地模式配置

1. 安装 Node.js 18+
2. 安装桥接依赖：

```bash
cd ai-book/cursor-bridge
npm install
```

3. 在 AIBook **设置** 中填写 Cursor API Key（或在环境变量中设置 `CURSOR_API_KEY`）
4. 顶栏右侧切换到 **Cursor 本地**（或在读书助手页使用已选模式），选中左页文字点击「讲解」，或在底部输入框继续追问

## 配置大模型

首次使用前，点击工具栏「大模型设置」：

| 提供商 | 默认 API 地址 | 默认模型 |
|--------|---------------|----------|
| OpenAI | https://api.openai.com/v1 | gpt-4o-mini |
| DeepSeek | https://api.deepseek.com/v1 | deepseek-chat |
| Ollama | http://127.0.0.1:11434/v1 | llama3.2 |
| 自定义 | 自行填写 | 自行填写 |

Ollama 本地运行示例：

```bash
ollama serve
ollama pull llama3.2
```

若 Ollama 启用了 `OLLAMA_API_KEY` 或使用需鉴权的远程地址，请在 **设置 → AI模型设置 → Ollama** 填写可选 API Key。

## 示例文件

`Sources/AIBook/Resources/sample.txt` 可用于快速体验。

## 项目结构

```
ai-book/
├── Package.swift
├── readme.txt
└── Sources/AIBook/
    ├── AIBookApp.swift
    ├── ContentView.swift
    ├── ReadingViewModel.swift
    ├── LLMService.swift
    ├── AppSettings.swift
    ├── SettingsView.swift
    ├── SelectableTextView.swift
    └── Resources/sample.txt
```
# ai-book

# ReadingViewModel 拆分设计

> 依据 [规约/方便人理解代码规约.md](../规约/方便人理解代码规约.md) 第 1 节：**单个类型不超过 800 行**（含 extension 加总）。  
> 改拆分方案时同步更新本文与 [aibook阅读模式.md](./aibook阅读模式.md) 中涉及的类型名。

## 当前超标类型（2026-03）

| 类型 | 约行数 | 优先级 | 状态 |
|------|--------|--------|------|
| `ReadingViewModel` | ~3540 | P0 | 已拆：五会话 + `ReadingMessageOrchestrator`（编排 ≤800 行） |
| `ContentView` | ~1650 | P0 | 待拆：工具栏 / 双页 / 全屏 overlay |
| `EvolutionExecutionViews.swift` 内多 View | 单类型均 &lt;800 | P2 | 可按文件拆到 `Evolution/` 多文件 |
| `ReadingSpreadView` | ~814 | P1 | 已拆：`ReadingSpreadSpreadBody` |
| `ExplanationChatView` | 已拆 | — | `ExplanationChatTranscriptView` 承载对话列表 |

## 拆分原则

1. **按变更原因拆类型**，不用 extension 文件绕开 800 行上限。
2. `ReadingViewModel` 保留为**编排入口**：绑定 UI、调用领域类型，不堆提示词/对齐/进化算法。
3. 新类型放在 `Sources/AIBook/Reading/`，文件名与主类型一致；同步 [Reading/功能说明.md](../../Sources/AIBook/Reading/功能说明.md)。

## 阶段计划

### 阶段 A（已完成）

- [x] `ReadingSpeechSource.swift`：`SpeechSource`
- [x] `ExplanationChatTranscriptView.swift`：右页消息列表
- [x] `ReadingViewModel` 顶部中文职责注释
- [x] `ReadingSpreadSpreadBody.swift`：翻页 spread 主体（`ReadingSpreadView` 保留顶栏与快捷键）

### 阶段 B：`ReadingViewModel` 组合拆分（已完成）

新增 `@MainActor` 类型，由 `ReadingViewModel` 持有并转发公开 API（避免一次性改 UI 绑定）：

| 新类型 | 职责 |
|--------|------|
| `ReadingDocumentSession` | 打开/保存/notes、选区、目录浏览 |
| `ReadingTranslationSession` | 译文内容、对齐、表格滚动、`TranslationPromptBuilder` 调用链 |
| `ReadingAssistantSession` | 讲解/名著补充、会话消息、流式输出 |
| `ReadingEvolutionSession` | 优化队列、分析/进化请求、token 预算 |
| `ReadingModeSession` | 阅读模式分页、spread 索引、持久化键 |
| `ReadingMessageOrchestrator` | LLM/Cursor 流式请求、`sendMessage` 状态机 |
| `ReadingViewModelSessionForwarding` | UI 兼容：会话字段与方法的 VM 转发 |

每拆出一类，从 `ReadingViewModel` 删除对应实现，并跑全量测试。

### 阶段 C：`ContentView` 拆分

| 新类型 | 职责 |
|--------|------|
| `ContentViewToolbar` | 顶栏、文档/讲解/翻译/朗读/进化工具栏 |
| `ContentViewLearningPanes` | 左页、书脊、右页、`ExplanationChatView` 容器 |
| `ContentViewFullscreenOverlay` | 右页全屏 overlay |

`ContentView` 只保留 `body`、sheet、模式切换。

## 文档同步（第 10 节）

| 改动 | 文档 |
|------|------|
| 阅读模式 / 翻页 | `docs/阅读/aibook阅读模式.md`、`同步滑动翻页设计.md` |
| 双页布局 / 工具栏 | `docs/UI/整体UI文档设计.md` |
| ViewModel 职责边界 | `docs/产品/整体功能文档设计.md` §2.1 |
| 源码目录 | `Sources/AIBook/Reading/功能说明.md` |

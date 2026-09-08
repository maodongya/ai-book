# AIBook 进化功能设计

> 文档性质：实现设计（基于当前源码与产品定义）  
> 关联文档：[整体功能文档设计.md](./整体功能文档设计.md) · [整体UI文档设计.md](./整体UI文档设计.md)  
> 产品定义（权威）：**使用 AI 模型，分析出 AIBook 可以优化的地方，分条目列到优化队列，然后使用进化功能按钮，进行 AIBook 的自动升级。**

---

## 1. 定义解读

进化功能由两段组成，顺序固定，不可颠倒：

| 阶段 | 谁做 | 产出 | 是否改源码 |
|------|------|------|------------|
| **分析** | AI 模型 | 分条目的优化队列 | 否 |
| **进化** | 用户点「进化」→ AI 改码 → 构建重启 | 应用自动升级 | 是 |

三条硬约束：

1. **队列是分析的结果，不是阅读原文。** 优化条目必须进入独立的优化队列，不能再把「当前左页全文」当成命令源。
2. **分析只诊断，不升级。** 分析阶段禁止 `edit` / `write` 源码，禁止构建重启。
3. **升级必须由「进化」按钮触发。** 点分析不等于改码；自动升级链只对**已在队列中且用户已启动过进化**的待办生效。

当前实现（`整体功能文档设计.md` §4.6）是「用户在左页手写编号命令 → 点进化执行」。这只覆盖了第二段。本设计补齐第一段，并把队列从左页文本中独立出来。

---

## 2. 现状与缺口

### 2.1 已具备、可复用

| 能力 | 位置 | 进化新定义中的角色 |
|------|------|--------------------|
| 编号命令解析 / Prompt 构建 | `EvolutionPlanner` | 执行阶段的任务描述仍可用 |
| 完成标记写回 | `SelfEvolution.applyCompletionFromReply` | 改为写回队列条目状态 |
| Cursor Agent 流式改码 | `CursorService` + `cursor-bridge` | 执行通道之一 |
| LLM 工具调用改码 | `LLMEvolutionAgent` + `EvolutionLocalTools` | 执行通道之二；分析阶段复用只读工具 |
| 构建安装并重启 | `AppRelauncher` + `scripts/build-and-install.sh` | 自动升级 |
| 跨重启继续 | `AutoEvolutionCoordinator` | 进化链，不用于分析 |
| 队列 UI 雏形 | `EvolutionCommandQueuePanel` | 升级为真正的优化队列 |
| Token 预算 / 停止 / 轨迹 | `ReadingViewModel` + `AssistantExecutionTraceCard` | 分析与进化共用展示 |

### 2.2 与定义不符的问题

| 问题 | 后果 |
|------|------|
| 队列解析自 `fileContent` | 打开任意 `.txt` 后，左页变成原文，队列消失或被正文里的「1、」误解析 |
| 没有「分析」动作 | 用户必须自己想优化点并手写命令，AI 不主动发现可优化处 |
| 分析与改码共用同一套可变工具 | 若把「分析」做成普通进化 Prompt，模型可能直接改文件 |
| 条目只有「一行字 + 完成标记」 | 无法表达优先级、类别、理由、影响文件，队列难以筛选 |
| 左页命令笔记与阅读抢同一块编辑器 | 读书与进化心智冲突（UI 文档 §3.6 / §7 P2） |

---

## 3. 方案比较与选择

### 方案 A：继续把左页当队列，只加「分析」按钮

分析完成后把编号行追加进 `readme-notes.txt`，进化流程不动。

- 优点：改动最小，现有解析器可继续用。
- 缺点：左页一旦打开书籍，队列丢失；分析与阅读互相覆盖；条目无法带结构化元数据。
- 结论：不满足「优化队列」作为一等公民。

### 方案 B：队列完全改成独立 JSON，左页不再参与进化

新建 `optimization-queue.json`，分析写 JSON，进化读 JSON。左页只负责读书。

- 优点：职责干净。
- 缺点：用户无法用纯文本快速改一条；与现有「编号命令」习惯断裂；迁移成本高。

### 方案 C（采用）：独立队列为唯一真源

- **唯一真源**：`~/Library/Application Support/AIBook/optimization-queue.json`
- **分析**写入该队列（结构化条目）
- **进化**只消费该队列的下一条待办
- **左页命令笔记**：不再是运行时解析源；仅作一次性迁移来源与用户自己的备忘文本
- 打开 `.txt` 阅读时，进化队列不受影响

选择 C 的原因：符合定义中的「优化队列」，保留手写/微调能力，且执行通道（Cursor / LLM / 构建重启）几乎不用重做。

---

## 4. 目标用户流程

```
打开 AIBook（可同时在读一本书）
        │
        ▼
  切到右页「AI进化」
        │
        ├──【分析优化】─────────────────────────────────┐
        │     AI 只读探索源码与产品定义                    │
        │     去重后写入优化队列（分条目）                 │
        │     队列 Tab 列出：待办 / 已完成 / 已跳过        │
        │     用户可改标题、删、跳过、调优先级、手写追加    │
        └──────────────────────────────────────────────┘
        │
        ▼
  【进化】（⌘E）
        │
        ▼
  取队列中优先级最高的一条待办
        │
        ▼
  AI 改码（Cursor 或 LLM 工具）→ 标记完成
        │
        ▼
  scripts/build-and-install.sh → 重启
        │
        ▼
  若「自动升级」开启且仍有待办 → 继续下一条
  否则停在新版本，等待用户再次点「进化」或「分析优化」
```

默认**不会**在启动时自动跑分析（费 Token、结果不稳定）。启动后自动继续的，只是已经开始的进化链。

---

## 5. 架构

```
┌─────────────────────────────────────────────────────────────────┐
│                      ReadingViewModel                            │
│  analyzeOptimizations()     startEvolution()                     │
└────────────┬───────────────────────────────┬────────────────────┘
             │                               │
    ┌────────▼────────┐              ┌───────▼────────┐
    │ EvolutionAnalyzer│              │ EvolutionPlanner│
    │ 只读 Prompt      │              │ 单条执行 Prompt │
    └────────┬────────┘              └───────┬────────┘
             │                               │
             │         ┌─────────────────────┼─────────┐
             │         │                     │         │
             ▼         ▼                     ▼         ▼
     LLMEvolutionAgent              CursorService
     (allowMutations: Bool)         (分析 Prompt 禁止改码)
             │                               │
             ▼                               ▼
     EvolutionLocalTools            cursor-bridge/explain.mjs
     分析：read / grep / glob       执行：完整工具链
     执行：+ edit / write / shell
             │
             ▼
     OptimizationQueueStore  ←── 唯一真源
             │
             ▼
     （仅执行成功后）AppRelauncher → AutoEvolutionCoordinator
```

### 5.1 新增 / 调整模块

| 模块 | 文件（建议） | 职责 |
|------|--------------|------|
| 队列条目 | `Sources/AIBook/Evolution/OptimizationItem.swift` | 条目模型、状态机、去重键 |
| 队列存储 | `Sources/AIBook/Evolution/OptimizationQueueStore.swift` | JSON 读写、合并、编号分配 |
| 分析器 | `Sources/AIBook/Evolution/EvolutionAnalyzer.swift` | 分析 Prompt、解析模型输出、合并策略 |
| 工具策略 | `EvolutionLocalTools` 扩展 | `mutating` 与 `readOnly` 两套工具定义 |
| 代理开关 | `LLMEvolutionAgent` | `allowMutations`；分析时 `maxIterations` 更小 |
| 编排 | `ReadingViewModel` | `analyzeOptimizations()`；`startEvolution()` 改读队列 |
| UI | `EvolutionExecutionViews` | 「分析优化」按钮；队列条目卡片 |

`SelfEvolution` 保留源码路径发现与状态文案；完成写回改为操作 `OptimizationQueueStore`，不再改左页 `fileContent`。

---

## 6. 优化队列数据模型

### 6.1 条目

```swift
struct OptimizationItem: Identifiable, Codable, Equatable {
    let id: UUID
    var number: Int                 // 展示用序号，从 1 递增，不复用
    var title: String               // 短标题，写入进化 Prompt
    var rationale: String           // 为何值得做（分析阶段必填；手写可空字符串）
    var category: Category          // ux / featureGap / stability / performance / maintainability
    var priority: Priority          // high / medium / low
    var risk: Risk                  // low / medium / high
    var suggestedFiles: [String]    // 相对源码根的路径，可空
    var source: Source              // ai / user
    var status: Status              // pending / running / completed / skipped
    var pinnedAt: Date?             // 非 nil 表示置顶；选择器先取 pinned
    var createdAt: Date
    var updatedAt: Date
    var completionSummary: String?  // 进化完成后的「已完成」摘要
}

enum Status: String, Codable {
    case pending, running, completed, skipped
}
```

状态只能按下列迁移：

```
pending → running → completed
pending → skipped
running → pending          // 用户停止或构建失败，回滚待办
skipped → pending          // 用户恢复
completed 不可再进入 running
```

同一时刻最多一条 `running`。

### 6.2 队列文件

路径：`~/Library/Application Support/AIBook/optimization-queue.json`

```json
{
  "version": 1,
  "updatedAt": "2026-09-08T15:00:00Z",
  "lastAnalysisAt": "2026-09-08T15:00:00Z",
  "items": []
}
```

首次启动：若 JSON 不存在，且 `readme-notes.txt` 里能解析出编号命令，则**一次性迁移**为 `source = user` 的条目，然后仍保留笔记文件（不删除，避免丢手写内容）。

### 6.3 下一条如何选

执行「进化」时取：

1. `status == pending`
2. 优先级 `high > medium > low`
3. 同优先级按 `number` 升序（先分析出来的先做）

用户在队列 UI 可将某条「置顶」，内部把该条 `priority` 提为 high 并记录 `pinnedAt`，选择器优先 pinned。

---

## 7. 分析阶段（新能力）

### 7.1 入口

| 入口 | 行为 |
|------|------|
| AI 进化面板按钮「分析优化」 | 唯一分析入口 |
| 队列为空时的空态按钮 | 调用同一 `analyzeOptimizations()` |

Composer 只用于进化追问（解释某次改码、问风险），**不**根据输入文本切换到分析，避免「请分析第 3 条为何失败」被当成重新入队。不新增分析快捷键。⌘E 仍只绑定「进化」。

### 7.2 分析输入（全部只读）

按优先级塞进 Prompt，受 Token 预算裁剪：

1. **产品定义**：`AIBookProduct` + `SelfEvolution.productDefinition`
2. **已有队列**：待办标题列表 + 已完成标题列表（去重用）
3. **能力对照**：`EvolutionAnalyzer.capabilityMap` 静态字符串（产品定位 + 现有模块一句话清单，约 30 行内；不把整份功能/UI 文档塞进 Prompt）
4. **源码探索**：分析 Agent 用 `glob` / `grep` / `read` 自行取证，不在第一轮把全部 Swift 塞进上下文
5. **聚焦说明**：不提供单独「分析提示」输入框。模型按 `capabilityMap` 与源码缺口自行排序；用户若要指定方向，先手写一条队列项再点「进化」

明确告诉模型：UI 文档里的 P0（读书助手对话区缺失）这类**用户可感知缺口**优先于重构、注释、重命名。

### 7.3 分析必须遵守的工具策略

| 工具 | 分析 | 进化 |
|------|------|------|
| `read` / `grep` / `glob` | 允许 | 允许 |
| `edit` / `write` | **拒绝**（返回明确错误，提示这是分析模式） | 允许 |
| `shell` | **拒绝**（避免 `swift build` 以外的副作用；分析不需要编译） | 允许（现有安全策略） |

Cursor 通道：分析 Prompt 写明「禁止修改任何文件；若已打开工作区也不得 apply diff」。若回复中出现改文件痕迹，以「未写入队列、请重试」失败，不把半成品当成功。

LLM 通道：`LLMEvolutionAgent.run(..., allowMutations: false)`，工具列表只用只读三项；`maxIterations` 建议 8（分析够用，比进化的 24 更省）。

### 7.4 分析输出格式

模型最后必须给出**可解析块**，展示给用户的自然语言可以在块之前：

```
<<<OPTIMIZATION_QUEUE>>>
[
  {
    "title": "读书助手展示讲解对话与流式输出",
    "rationale": "当前讲解结果只朗读不显示，追问看不到历史。",
    "category": "ux",
    "priority": "high",
    "risk": "medium",
    "suggestedFiles": [
      "Sources/AIBook/Reading/ExplanationChatView.swift",
      "Sources/AIBook/Reading/ReadingAssistantPanel.swift"
    ]
  }
]
<<<END>>>
```

解析失败时：尝试从「1、标题」编号列表降级提取；仍失败则不改队列，在进化对话区提示。

### 7.5 合并规则（写入队列）

对每一条候选：

1. 与现有 **pending / running / skipped / completed** 做去重：将标题去掉首尾空白、压缩连续空白、统一中文标点 `，。；：、` 后再比，**仅完全相等**视为重复（不用包含匹配，避免短标题误伤）。
2. 命中任一已有条目 → **丢弃**（不复活已完成或已跳过项；用户若要重做，在队列里手写一条新标题）。
3. 未命中 → 分配新 `number = max(existing)+1`，`source = ai`，`status = pending`。
4. 单次分析最多写入 **8** 条；超出部分丢弃并在回复中说明「其余未入队，可再次分析」。
5. 单次分析 **最少 1 条**；若模型认为没有可优化点，允许空结果，UI 显示「未发现新的优化项」。

分析**不删除**用户手写条目，不重排已有 pending 的 number。

### 7.6 分析成功后的 UI

- 切到「队列」子 Tab
- 对话区留下一条助手消息：发现 N 条、入队 M 条、去重跳过 K 条
- 可展开 Agent 轨迹（只读工具步骤）
- **不**调用 `AppRelauncher`，**不**置 `auto-evolution-active`

---

## 8. 进化阶段（在现有闭环上改数据源）

### 8.1 触发

与现在相同：顶栏 / 面板「进化」、⌘E。前置条件改为：

1. AI 后端已配置（`AppGuard`）
2. 源码目录可定位（`SelfEvolution.sourceProjectReady`）
3. Token 未超限
4. 队列中存在 `pending`
5. 当前没有分析或进化在跑

若队列为空：提示「请先点「分析优化」，或在队列中手写一条」，**不要**再报「左页没有编号命令」。

### 8.2 执行 Prompt

`EvolutionPlanner.buildEvolutionPrompt` 改为吃 `OptimizationItem`，不再拼左页全文：

```
【AIBook 产品定义】…
【优化队列摘要】编号 + 状态 + 标题（全部条目，供避让与上下文）
【当前待进化】
- 编号、标题、理由、类别、优先级、风险
- 建议文件：…
【源码目录】…
【本次任务】
（保持现有 8 条执行纪律：先分析范围 → 最小改动 → BookTheme → swift build → 一行完成摘要）
```

完成摘要格式改为机器可解析：

```
<<<EVOLUTION_DONE>>>
{"number": 12, "summary": "读书助手增加讲解对话区"}
<<<END>>>
```

同时允许旧格式 `12、已完成：…` 作为降级，便于现有 `applyCompletionFromReply` 逻辑迁移。

### 8.3 执行中状态

1. 将该条 `pending → running`
2. `executingEvolutionCommandNumber = item.number`
3. 流式展示思考 + 工具（现有轨迹卡）
4. 成功：`running → completed`，写入 `completionSummary`
5. 用户停止或 Agent 失败：`running → pending`，不构建
6. 仅当本条标记 completed 后才 `rebuildAndRelaunch`

构建失败：条目保持 `completed`（码已改）或回 `pending`？选定：**保持 completed，但清除进化链标志**，并在对话区报告构建失败。避免同一条被重复改码造成更大损坏。用户可手写「修复构建」新条目。

### 8.4 自动升级链

设置项 `autoEvolutionEnabled` 语义收窄为：

> 进化按钮启动过之后，若队列仍有 pending，则打包重启后自动执行下一条。

不因「队列里有 AI 分析出来的条目」就在冷启动 2.5s 后偷偷进化。实现：

- `AutoEvolutionCoordinator.markChainActive()` **只在** `startEvolution()` 成功开始执行时调用
- `scheduleAutoEvolutionIfNeeded()` 必须同时满足：开关开、`isChainActive`、存在 pending
- 「分析优化」以及用户仅打开 App 看书，都不得 `markChainActive`

队列全部完成后：构建重启一次，然后 `clearChain()`，不再空转重启（修复当前「命令已全部完成 · 将自动重启」的多余重启）。

---

## 9. 双通道行为

| | Cursor 本地 | 大模型 API |
|--|-------------|------------|
| 分析 | 只读 Prompt + 检查回复未改文件 | `allowMutations: false` 工具循环 |
| 进化 | 现有 Agent 工具链 | 现有 `EvolutionLocalTools` 全量 |
| 回退 | Cursor 鉴权失败且 LLM 已配置 → 回退 LLM（与现网一致） | Ollama 无工具能力：分析可纯文本 JSON；进化则只能出方案不能改文件，UI 需提示换模型 |

分析与进化共用顶栏/面板里的后端切换，不另做一套模型配置。

---

## 10. 界面

在现有 `EvolutionUtilityTabsPanel` 上增量，不重做书籍风格。

### 10.1 「进化」子 Tab 操作行

```
[分析优化]  [进化]  [停止?]              第 N 条 / 分析中
```

- 运行中只保留「停止」
- 「分析优化」在 `isRunning` 或 `isEvolutionRebuilding` 时禁用
- 「进化」在无 pending 或 Token 超限时禁用（空态引导去分析）

### 10.2 「队列」子 Tab

替换「左页编号芯片横滑」为条目列表：

- 每条：`#编号`、标题、类别色点、优先级、来源（AI / 手写）、状态
- 待办可：跳过、删除、置顶、编辑标题
- 底部：`+ 添加优化项`（手写，`source = user`）
- 源码路径仍显示在底部
- 空态文案改为：「点「分析优化」，让 AI 找出可改进处」

顶栏进化状态胶囊改为读队列：`待优化 N 条 · 下一条 #12 读书助手对话区`。

### 10.3 左页

打开书籍时左页只显示原文。进化不再要求用户切回命令笔记。  
未打开文件时，左页仍可编辑 `readme-notes.txt`，但**运行时进化不再读取该文件**。首次启动的一次性迁移之后，笔记与队列不再同步，避免分析结果冲掉用户正在写的字。不在首版做「导入/导出笔记」按钮。

---

## 11. 安全与边界

沿用并强化现有沙箱：

| 规则 | 说明 |
|------|------|
| 路径沙箱 | 读写仍限制在 ai-book 源码根（含 `Package.swift` 的目录） |
| 分析无写 | 只读工具；队列 JSON 由 Swift 代码写，不由模型直接 `write` |
| Shell 策略 | 仅进化阶段，沿用 `EvolutionLocalTools` 过滤 |
| 单任务 | 全局一次运行：分析与进化互斥 |
| Token | 分析与进化都走 `ModelTokenBudget`，超限阻止发送 |
| 单条进化 | 一次只改一条队列项，降低一次重启引入多处回归的风险 |
| 不提交 git | 进化 Agent Prompt 写明不要 `git commit` / `git push`（应用自己也不自动 commit） |

已知边界（写入功能文档同类）：

- 无源码目录（纯安装包、找不到 `Package.swift`）时，分析与进化均不可用，需明确报错
- 分析质量取决于模型；必须去重与条数上限，避免队列被灌垃圾
- Cursor / 弱工具模型可能不遵守「只读」——以工具层拒绝为准，不以模型自觉为准

---

## 12. 实现顺序

分步任务、测试与提交说明见独立文档：[aibook进化实现计划.md](./aibook进化实现计划.md)。

合入顺序与该计划的 Task 分组一致：

1. **队列独立**（Task 1–6）：Store + 进化改读队列 + 自动升级门闩 + 队列 UI。此阶段不改 `LLMEvolutionAgent` 主循环。
2. **分析优化**（Task 7–9）：解析器、只读工具、`分析优化` 按钮。
3. **队列操作与文案**（Task 10–11）：跳过/删除/置顶/手写、文档同步。

---

## 13. 关键接口（供实现时对齐）

```swift
enum OptimizationQueueStore {
    static func load() throws -> OptimizationQueue
    static func save(_ queue: OptimizationQueue) throws
    static func migrateFromReadmeNotesIfNeeded(_ notes: String) throws
}

enum EvolutionAnalyzer {
    static func buildAnalysisPrompt(
        queue: OptimizationQueue,
        projectPath: String
    ) -> String

    static func parseItems(from reply: String) -> [OptimizationDraft]
}

extension OptimizationQueue {
    mutating func merge(drafts: [OptimizationDraft], maxNewItems: Int = 8) -> MergeReport
    func nextPending() -> OptimizationItem?
    mutating func markRunning(id: UUID)
    mutating func markCompleted(id: UUID, summary: String)
    mutating func revertRunningToPending(id: UUID)
}

extension ReadingViewModel {
    func analyzeOptimizations()
    func startEvolution()   // 现有方法，改为消费 nextPending()
}
```

`LLMEvolutionAgent.run` 增加：

```swift
allowMutations: Bool = true
maxIterations: Int? = nil
```

分析调用：`allowMutations: false`，`maxIterations: 8`。

---

## 14. 验收标准

定义落地即以下全部成立：

1. 用户**不写**左页命令，只点「分析优化」，队列中出现至少一条带理由的优化项。
2. 分析过程中源码目录无文件被修改（可用 `git status` 验证）。
3. 打开任意书籍 `.txt` 后，队列仍在，「进化」仍执行队列而非书籍正文。
4. 点「进化」只处理一条 pending：改码 → 标记完成 → 构建安装 → 重启。
5. 未点过「进化」时，冷启动不会因为队列非空而自动改码。
6. 点过「进化」且自动升级开启、仍有 pending 时，重启后继续下一条。
7. 用户可跳过/删除/手写追加条目；AI 再次分析不会重复已完成或已在待办中的项。
8. Token 超限、未配置后端、找不到源码时，分析与进化都被拦截并给出中文原因。

---

## 15. 对现有文档的影响

| 文档 | 需要同步的点 |
|------|----------------|
| `整体功能文档设计.md` §4.6 | 从「左页编号命令驱动」改为「分析入队 + 进化升级」；命令笔记不再作为运行时队列 |
| `整体功能文档设计.md` §6.1 | 增加 `optimization-queue.json` |
| `整体UI文档设计.md` §3.9 / §4.4 | 增加「分析优化」；队列不再依赖左页 |
| `EvolutionAssistant.welcomeMessage` | 说明先分析再进化 |
| `AIBookProduct.aboutLines` | 「按左页编号命令自我进化」改为「AI 分析优化队列并一键升级」 |

本文档是进化功能的实现依据；功能总文档在本设计落地后按上表修订，避免两套说法并存。

---

*本设计针对仓库当前 Swift / macOS 实现归纳，分析阶段为新增，进化执行与构建重启复用现有闭环。*

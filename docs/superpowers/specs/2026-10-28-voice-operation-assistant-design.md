# 语音智能操作助手设计

## 背景

AIBook 已有讲解、翻译、朗读、阅读布局、书库和进化。朗读是文字转语音。用户不能用说话来驱动这些功能。

本设计增加一条语音操作链路：按住说话，系统语音识别成文字，用当前读书模型把这句话解析成封闭目录里的功能操作，再由软件调用现有功能执行。

## 目标

- 顶栏麦克风按住说话、松开后执行；应用在前台时，按住 Option+空格 等价。
- 识别结果交给当前读书后端（`AppSettings.explanationSource`：大模型 API 或 Cursor 本地）做一轮解析。
- 模型只能从本文登记的操作里点名。安全操作按顺序马上执行。
- 开始进化和分析优化先确认。用户取消时，该步和它后面的步骤不执行。
- 听不清、对不上目录、解析失败时不执行，并显示听到的文字和「没有对应操作」。听不清时不请求模型。
- 界面显示正在听、听到的文字、正在做的操作或跳过原因。成功和失败不弹窗。

## 非目标

- 不持续监听，不在后台全局热键里听。
- 不做多轮操作对话，不把上一句操作历史发给模型。
- 不把全文、整段选区或源码放进操作请求。
- 不新增操作模型档案，不跟随进化专用后端。
- 不登记改模型、改主题、改界面语言、改语言勾选、删除文件、按模型给出的路径写文件。
- 不把语音识别和真实模型请求放进单元测试。

## 数据流

1. 用户按住麦克风或 Option+空格。
2. `SFSpeechRecognizer` 把语音转成文字。系统语言有端侧识别时只用端侧识别。
3. 松开时没有文字：状态写「没听清」，结束。
4. 组装界面快照和操作目录，向当前读书模型发一轮请求。
5. 校验返回的操作名和参数。空列表、无法解析、或全部被丢掉时，状态写「没有对应操作」，结束。
6. 按顺序执行。需要确认的步骤弹出确认；取消则停下，已执行的步骤保留。
7. 每一步的结果写到同一条状态里。

## 操作目录

操作名稳定，用英文标识。参数只有下面列出的字段。目录外的名字丢掉。

马上执行：

| 操作 | 参数 | 调用 |
|------|------|------|
| `explainSelection` | 无 | `explainSelection()` |
| `explainFullText` | 无 | `explainFullText()` |
| `translateWordByWord` | 无 | `generateLessonPlan()` |
| `translateParagraph` | 无 | `refineLessonPlan()` |
| `readOriginalSelection` | 无 | `readOriginalSelectionAloud()` |
| `readOriginalFull` | 无 | `readOriginalFullTextAloud()` |
| `readTranslationSelection` | 无 | `readTranslationSelectionAloud()` |
| `readTranslationFull` | 无 | `readTranslationFullTextAloud()` |
| `readExplanationSelection` | 无 | `readExplanationSelectionAloud()` |
| `readExplanationFull` | 无 | `readExplanationFullTextAloud()` |
| `pauseSpeech` | 无 | `toggleExplanationSpeechPause()`，仅在正在朗读时 |
| `resumeSpeech` | 无 | `toggleExplanationSpeechPause()`，仅在已暂停时 |
| `stopSpeech` | 无 | `stopExplanationSpeech()` |
| `stopCurrentRun` | 无 | `stopCurrentRun()` |
| `toggleReadingMode` | 无 | 现有阅读模式切换。页尺寸由界面注入 |
| `setPaneFocus` | `focus`: `both` / `leading` / `trailing` | `ContentView.setLearningPaneFocus`，由界面注入 |
| `showAssistantPanel` | `panel`: `explanation` / `translation` | 切到读书助手，再 `selectReadingAssistantPanel` |
| `showRightPage` | `page`: `assistant` / `evolution` | 只切换右页，不开始进化 |
| `showExplanationLanguage` | `language`: 已启用语言的 rawValue | `ReadingExplanationLanguages.show` |
| `showTranslationLanguage` | `language`: 已启用语言的 rawValue | `showTranslationLanguage` |
| `openLibraryFile` | `query`: 文件名 | 在已索引书库里按文件名匹配 |
| `openFilePanel` | 无 | `openFile()` |
| `openDirectoryPanel` | 无 | `openDirectory()` |
| `save` | 无 | `save()` |
| `saveAs` | 无 | `saveAs()`，系统面板负责是否替换 |
| `saveSelectionAs` | 无 | `saveSelectionAs()` |
| `saveAsAIBook` | 无 | `saveAsAIBook()` |
| `selectAllLeft` | 无 | `selectAllLeftPage()` |
| `selectAllRight` | 无 | `selectAllRightPage()` |
| `supplementClassic` | 无 | `supplementClassicLiterature()` |

先确认再执行：

| 操作 | 调用 |
|------|------|
| `startEvolution` | `startEvolution()` |
| `analyzeOptimizations` | `analyzeOptimizations()` |

讲解和翻译不接收语言参数，生成语言仍是当前勾选集合，和点工具栏按钮相同。`showExplanationLanguage` / `showTranslationLanguage` 只切换右页已经生成的内容，不改勾选，不发起新的生成。

用户在同一句里指定了语言，又要求讲解或翻译时：

- 该语言在对应勾选集合里：计划里只保留讲解或翻译操作。
- 该语言不在勾选集合里：执行器丢掉同一计划中的讲解、翻译和切语言，状态说明该语言未启用。不改设置，也不改用其它语言生成。计划里其余安全步骤仍按顺序继续。

`openLibraryFile` 只比较书库索引中的文件名，忽略大小写。恰好一本时打开。零本或多本时跳过这一步并说明原因，不猜。

## 上下文

用户消息是一句识别文字加一份 JSON 快照。快照包含：

- 文件名、是否已有保存路径、是否有未保存修改
- `hasSelection`，以及选区开头最多 80 个字符
- 学习模式或阅读模式、`LearningPaneFocus`
- 右页是助手还是进化，助手子栏是讲解还是翻译
- 当前显示的讲解语言、翻译语言
- 已勾选的讲解语言、翻译语言
- 朗读状态：空闲、正在读、已暂停
- `isRunning`
- 书库文件名，最多 40 个；超过时带 `libraryTruncated: true`

快照不包含选区第 81 个字符之后的内容，也不包含文件正文。

## 请求与解析

每次松开麦克风只发一轮，`temperature` 沿用 `completeWithTools` 的 0.2。不附带操作历史。

大模型 API：调用现有 `LLMService.completeWithTools`，工具表就是操作目录。只读取这一轮的 `tool_calls`，不把工具结果发回模型。模型不支持工具时，改为要求正文只含 JSON：`{"actions":[{"name":"…","arguments":{}}]}`。没有 `tool_calls` 时，也尝试从正文解析这份 JSON。

Cursor 本地：`sessionMode = analysis`，`freshAgent = true`，`closeAgentAfterRun = true`，`autoAuthorize = false`，历史为空。系统提示要求只返回上述 JSON，并禁止改文件和使用仓库工具。桥接若仍产出工具事件，忽略这些事件，只解析最终正文。

解析规则：

- 操作按返回顺序保留。
- 未知名字、缺参数、参数不在枚举内的项丢掉。
- 丢掉之后一个不剩，或正文无法解析：不执行，状态为「没有对应操作」。
- 网络、密钥、桥接失败：不执行，状态显示现有错误文案。

## 执行

执行器只调用目录里写明的现有方法，不另写一套讲解或翻译。

前提不满足时跳过该步，把原因写入状态，然后继续后面的安全步骤。前提包括：没选区却要处理选区、正文为空却要处理全文、语言未启用、语言已启用但右页还没有该语言内容、书库匹配不是恰好一本、当前没有朗读却要暂停或停止朗读。

`isRunning == true` 时，计划里只执行 `stopCurrentRun` 和朗读的暂停、继续、停止。其它步骤跳过，并说明正在生成。

确认步骤使用系统确认框，框内有听到的文字和操作的本地化名称。确认后继续该步和后面的步骤。取消后该步和后面的步骤都不执行。确认框显示期间忽略新的按住说话，避免两套计划交错。

`setPaneFocus` 和 `toggleReadingMode` 需要窗口状态，由 `ContentView` 把现有方法注入执行器。执行器不直接写 SwiftUI 的 `@State`。

## 界面

- 学习模式顶栏增加麦克风。按住开始听，松开结束并进入解析。
- 阅读模式顶栏不可用时，前台按住 Option+空格 仍然有效。SwiftUI 的 `keyboardShortcut` 不能表达按住，使用本应用的本地按键监视。
- 听的时候按钮高亮，状态为「正在听」。
- 同一条状态依次显示听到的文字、当前步骤、跳过原因或「没有对应操作」。状态留到下一次说话，可手动关掉。
- 首次使用请求麦克风和语音识别权限。拒绝后按钮说明如何在系统设置里打开，不开始听。
- `App/Info.plist` 增加 `NSMicrophoneUsageDescription` 和 `NSSpeechRecognitionUsageDescription`，文案为简体中文。
- 状态和确认文案进入 `Localizable.xcstrings`，经现有本地化表生成。

## 模块

新代码放在 `Sources/AIBook/Operation/`，并写 `功能说明.md`。每个类型只做一件事：

| 类型 | 职责 |
|------|------|
| `OperationSpeechCapture` | 按住听写，产出文字或权限/识别失败 |
| `OperationCatalog` | 操作名、参数、是否需要确认 |
| `OperationContextSnapshot` | 从当前会话生成快照 |
| `OperationPromptBuilder` | 系统提示和工具表 |
| `OperationPlanner` | 一轮请求和解析，返回 `OperationPlan` |
| `OperationExecutor` | 前提检查、确认暂停、调用现有功能 |
| `OperationAssistantModel` | 听写、计划和状态，供顶栏绑定 |

`OperationPlanner` 依赖现有 `LLMService` 与 `CursorService`，由调用方传入。执行器依赖现有会话方法的闭包，便于测试时替换。

新 Swift 遵守仓库中文文档注释和行尾注释规约。单个类型不超过 1000 行。

## 测试

测试放在 `Tests/AIBookL10nTests`，`@testable import AIBook`。语音识别和网络用假回复代替。

- 解析合法列表、未知名字、空列表、多步顺序，以及有效项和无效项混在一起时只保留有效项。
- 快照不含正文其余部分；选区摘录不超过 80 字；书库文件名不超过 40 个。
- 没选区、语言未启用、书库零本或多本时，执行器不调用对应功能。
- `startEvolution` 和 `analyzeOptimizations` 在确认前不被调用；取消后后续步骤不被调用。
- `isRunning` 时讲解和翻译不被调用，`stopCurrentRun` 会被调用。

## 文档

实现时同步：

- `docs/产品/整体功能文档设计.md` 与 `docs/产品/功能说明书.md`
- `Sources/AIBook/Resources/功能说明书.md`
- `docs/UI/整体UI文档设计.md` 中的顶栏说明
- `Sources/AIBook/Operation/功能说明.md`

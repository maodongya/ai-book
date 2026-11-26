# AIBook iOS 升级优化清单

> **文档性质**：对照 [`iOS界面设计.md`](./iOS界面设计.md) 与当前 `Sources/AIBookIOS/` 实现的差距审阅，列出可做的合理优化。  
> **审阅日期**：2026-11-25  
> **不含**：Mac 窗口、进化、Cursor 相关改动（见 [`功能说明.md`](../../Sources/AIBookIOS/功能说明.md)）。

---

## 1. 审阅结论摘要

iOS 壳已覆盖：**单页/宽屏并排、原文编辑、讲解/翻译请求、对照表、阅读翻页、种子书、`.aibook`、语音口令、八种界面语言与风格预设**。  
与 design 稿和 Mac 能力相比，主要缺口在：**主导航形态**、**翻译/讲解对齐与锁定**、**阅读分页精度**、**设置与 Mac 模型偏好同步**、**朗读/语音设置**、**工程化测试**。

---

## 2. 优先级说明

| 级别 | 含义 |
|------|------|
| **P0** | 与设计稿明显不符或易用性硬伤，建议优先 |
| **P1** | 功能完整性 / 与 Mac 契约不一致，中期 |
| **P2** | 体验打磨、工程债、可随版本迭代 |

---

## 3. 导航与信息架构

| 级别 | 项 | 现状 | 建议 |
|------|-----|------|------|
| ~~P0~~ | **底栏四入口** | ✅ `IOSBottomTabBar`：原文 / 讲解 / 翻译 / 阅读；沉浸阅读时隐藏 | — |
| ~~P0~~ | **右上角「更多」** | ✅ `IOSBookMoreMenu`：设置、说明书、隐私、保存 `.aibook` | 页内 ⋯ 仍保留本页操作 |
| ~~P1~~ | **换页按钮一致性** | ✅ 页内 ⋯ 统一 `ellipsis.circle.fill` + 44pt | 原文标题仍可迁 `IOSPageHeading` |
| ~~P1~~ | **阅读入口可见性** | ✅ 底栏「阅读」入口 | — |
| ~~P2~~ | **半圆气泡遗留** | ✅ 删 `IOSBubbleMotion`；`IOSShellModel` 只留页态 | 左缘 `IOSBubbleMenu` 保留 |
| ~~P1~~ | **iPad 宽屏右半切换** | ✅ `IOSSplitAssistantPane` 分段 | — |

---

## 4. 原文页

| 级别 | 项 | 现状 | 建议 |
|------|-----|------|------|
| ~~P1~~ | **页底工具条** | ✅ 原文页 `safeAreaInset` 底栏：保存、另存、补充、全选 | — |
| ~~P1~~ | **拖放打开** | ✅ `onOpenURL` + 根视图 `dropDestination` | — |
| ~~P2~~ | **未保存提示** | ✅ 底栏切页时 `alert.discard.*` 确认 | 新建仍走原文页菜单 |
| ~~P2~~ | **选区条位置** | ✅ 选区条 `safeAreaInset` 底栏上浮 | — |

---

## 5. 讲解页

| 级别 | 项 | 现状 | 建议 |
|------|-----|------|------|
| ~~P1~~ | **追问** | ✅ `appendExplanation` 追加追问结果 | Mac 线程 UI 仍不同 |
| ~~P1~~ | **多语言顺序生成** | ✅ 讲解/整段翻译按 `ExplanationTargetLanguageStore` / `TranslationTargetLanguageStore` 串行，页顶显示 `translation.progress.language` | 逐字翻译仍单语 |
| ~~P1~~ | **对齐 / 锁定** | ✅ 改原文标 stale；译文/讲解菜单锁定；对齐讲解/翻译 | JSON 严格对齐仍待 Mac 级 |
| ~~P2~~ | **讲解对照** | ✅ 点原文格回跳并高亮 | — |
| ~~P2~~ | **语言分段文案** | ✅ `IOSLanguageLabels` | — |
| ~~P2~~ | **自动朗读** | ✅ 设置朗读栏「朗读」开关 + 多语言末段朗读 | — |

---

## 6. 翻译页

| 级别 | 项 | 现状 | 建议 |
|------|-----|------|------|
| ~~P0~~ | **对照质量** | ✅ `.aibook` 的 `translationAlignment` / `explanationAlignment` 按块对照；无对齐时仍按空行配对 | P1：对照高亮、可编辑格 |
| ~~P1~~ | **对照高亮** | ✅ 选区或 `readingCharacterAnchor` 高亮并滚动 | — |
| ~~P1~~ | **对齐 / 锁定 / 菜单项** | ✅ 翻译/讲解 ⋯ 锁定与「对齐原文」 | 可编辑格待 P2 |
| ~~P2~~ | **对照表编辑** | ✅ 对照模式译文/讲解格 `TextEditor` 写回 | Mac 表格级编辑仍不同 |
| ~~P2~~ | **列头** | ✅ `IOSCompareList` 首行 | — |
| ~~P2~~ | **语言分段** | ✅ 同上 | — |

---

## 7. 阅读页

| 级别 | 项 | 现状 | 建议 |
|------|-----|------|------|
| ~~P0~~ | **分页算法** | ✅ `IOSBookPaginator`（TextKit + 阅读字号/行距/边距） | P1：旋转后字符位置恢复 |
| ~~P1~~ | **旋转 / 改字号** | ✅ `readingCharacterAnchor` 重分页后回附近页 | — |
| ~~P1~~ | **页脚文案** | ✅ `vm.page.single` | — |
| ~~P1~~ | **iPad 双页** | ✅ 横屏双页 + `layout.spread` 开关 + `aiBook.ios.readingDualPage` | 竖屏仍单页 |
| ~~P2~~ | **顶栏** | ✅ 阅读中间点按显隐顶栏，4 秒自动藏 | — |
| ~~P2~~ | **双页/单页偏好** | ✅ `aiBook.ios.readingDualPage` | — |
| ~~P2~~ | **麦克风重复** | ✅ 阅读时根级麦克风隐藏 | — |

---

## 8. 设置、模型与 Mac 共用

| 级别 | 项 | 现状 | 建议 |
|------|-----|------|------|
| ~~P1~~ | **模型偏好键** | ✅ 迁到 `aiBook.book.*`，旧 `ios.*` 自动迁移 | — |
| ~~P1~~ | **讲解/翻译目标语言** | ✅ `IOSBookLanguageSettings` + 节选占比 | — |
| ~~P1~~ | **朗读设置** | ✅ 语速档 + 滑条落盘 | 在线声音列表待做 |
| ~~P2~~ | **说明书 / 隐私** | ✅ `PrivacyPolicy.publicURL` 非空时 `Link` | 上架前填 URL |
| ~~P2~~ | **外接键盘** | ✅ ⌘⇧R 阅读、⌘. 停止 | 更多快捷键待补 |

---

## 9. 数据、`.aibook` 与网络

| 级别 | 项 | 现状 | 建议 |
|------|-----|------|------|
| ~~P1~~ | **对齐 sidecar** | ✅ P0 已读 alignment | — |
| ~~P1~~ | **保存 `.aibook`** | ✅ P0 已写 alignment | — |
| ~~P2~~ | **流式输出** | ✅ `IOSChatClient` SSE + 设置开关；讲解/译文增量 `store*` | 名著补充仍整段写回 |
| ~~P2~~ | **错误文案** | ✅ `IOSLLMErrorMessage` 映射密钥/HTTP | 提供商细化待 Mac 级 |
| ~~P2~~ | **目录书签** | ✅ `IOSDirectoryBookmark` | 书签失效时静默忽略 |

---

## 10. 语音与朗读

| 级别 | 项 | 现状 | 建议 |
|------|-----|------|------|
| ~~P1~~ | **口令覆盖** | ✅ 对齐与翻译/讲解锁定口令已接 `IOSVoiceController` | 对照表开关等待 UI 状态 |
| ~~P2~~ | **听到文字** | ✅ 松手 3 秒后清空 `heard` | — |
| ~~P2~~ | **朗读条来源** | ✅ `IOSSpeaker.contextTitleKey` + 顶栏标签 | — |

---

## 11. UI 与无障碍

| 级别 | 项 | 现状 | 建议 |
|------|-----|------|------|
| ~~P1~~ | **对照表动态字体** | ✅ `fixedSize` + `layoutPriority` + VoiceOver 段标签 | 极大字号实机抽测仍建议 |
| ~~P2~~ | **触控目标** | ✅ 更多菜单 `ellipsis.circle.fill` 44pt | — |
| ~~P2~~ | **VoiceOver** | ✅ 对照格「段号 + 列名 + 正文」 | — |
| ~~P2~~ | **深色模式** | ✅ 对照格线在 dark 下提高不透明度 | 实机抽测仍建议 |

---

## 12. 工程与质量

| 级别 | 项 | 现状 | 建议 |
|------|-----|------|------|
| ~~P1~~ | **UI 测试** | ✅ `AIBookIOSUITests` + `-SnapshotTranslationCompare`；底栏 `ios.tab.*` / 对照 `ios.compareList` | 真机截图断言待扩展 |
| ~~P1~~ | **CI** | ✅ `.github/workflows/ios-tests.yml` 跑 `AIBookIOSTests` | 模拟器机型随 GitHub 镜像更新 |
| ~~P2~~ | **死代码** | ✅ 去掉 `IOSBubbleMotion`；快照见 `功能说明.md` | `IOSSnapshotHints` 仍 DEBUG |
| ~~P2~~ | **共享代码** | ✅ Shared 组白名单；`BookStyleTokens` 双端分支已文档化 | 不把 Mac 窗口代码编入 iOS |
| ~~P2~~ | **注释规约** | ✅ 本轮新建/拆分工具文件已补行尾注释（`IOSAlignmentSync`、`IOSLayout`、`IOSDirectoryBookmark`、`IOSLLMErrorMessage` 等）；其余目录仍按需补，避免机械刷全库 | 可用 `scripts/add_swift_trailing_line_comments.py` 初稿后人工润色 |

---

## 13. 建议迭代顺序（路线图）

1. **导航定稿**（P0）：底栏 vs 左上菜单 — 与产品确认后改代码或改设计稿。  
2. **翻译对照深化**（P0–P1）：对齐数据 + 高亮 + 可编辑格。  
3. **阅读分页**（P0–P1）：真实排版分页与进度记忆。  
4. **设置与 Mac 对齐**（P1）：模型键、目标语言、朗读。  
5. **讲解追问与多语言**（P1）。  
6. **工程**（P1–P2）：XCUITest、CI、拖放打开。

---

## 14. 近期已修（供回归）

| 日期 | 项 |
|------|-----|
| 2026-11-25 | 原文页补上左侧 `IOSBubbleMenu` |
| 2026-11-25 | 翻译/讲解对照改为 `IOSCompareList` 方格线表 |
| 2026-11-25 | `IOSSourcePage` 语法修复；`BookStyleTypography.uiFont` 供 iOS 编辑器 |
| 2026-11-25 | DEBUG `-SnapshotTranslationCompare` 便于模拟器对照截图 |
| 2026-11-26 | P0：底栏、`IOSBookMoreMenu`、对齐对照、TextKit 阅读分页 |
| 2026-11-26 | P1：设置与 Mac 键、对照高亮、阅读锚点、原文底栏、追问追加、iPad 分段、锁定翻译 |
| 2026-11-26 | P1：多语言串行、对齐按钮、讲解锁定、拖放、iPad 双页、口令对齐/锁定、CI |
| 2026-11-26 | P1：阅读锚点↔对照高亮、`AIBookIOSUITests` |
| 2026-11-26 | P2：对照列头/编辑/点回原文、未保存确认、朗读条标签、隐私 Link、LLM 错误文案 |
| 2026-11-26 | P2：精简 Shell、阅读顶栏、目录书签、自动朗读、键盘快捷键、选区底栏 |
| 2026-11-26 | P2：SSE 流式讲解/翻译、Shared 编译说明 |
| 2026-11-26 | P2：`ios.settings.streamResponses` 文案、工具类行尾注释、目录/SSE 行注释 |

---

## 15. 相关文件索引

| 区域 | 入口 |
|------|------|
| 根布局 | `IOSRootView.swift` |
| 换页 | `IOSBubbleMenu.swift`, `IOSShellModel.swift` |
| 对照 | `IOSCompareList.swift`, `IOSParagraphPairs.swift` |
| 阅读 | `IOSReadingPage.swift`, `IOSReadingPages` |
| 设计稿 | `docs/UI/iOS界面设计.md` |

---

*本清单随实现更新；完成某项后可在 §14 记录并下调对应优先级。*
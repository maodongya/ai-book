# AIBook 阅读模式设计

> 文档性质：实现设计  
> 关联：`ContentView` · `ReadingViewModel` · `BookPaginator` · `ReadingSpreadView`

---

## 1. 背景

AIBook 读书功能包含两种体验：

| 模式 | 用途 | 布局 |
|------|------|------|
| **学习模式** | 讲解、翻译、朗读、名著补充、AI 进化 | 左页原文 + 右页 AI（现有实现） |
| **阅读模式** | 连续沉浸阅读 | 全屏双页 spread，左第 N 页、右第 N+1 页，可翻页 |

阅读模式不提供 AI；需要讲解时切回学习模式。

---

## 2. 交互规格

### 2.1 进入 / 退出

- 顶栏「阅读模式」按钮（有正文时可用）进入全屏阅读。
- 阅读模式顶栏：返回学习模式、文件名、页码。
- 快捷键：`⌘⇧P` 进入阅读模式（有正文时）；阅读模式内 `Esc` 返回学习模式。

### 2.2 翻页

| 方式 | 行为 |
|------|------|
| `←` / `→` | 上一跨页 / 下一跨页 |
| 点击左/右页 | 同上 |
| 水平滑动 | 跟手卷曲；超过约 1/3 松手即翻完，否则回弹 |
| 动画 | 双页正反 + 折痕阴影 + 下层 spread 渐显 + 弹簧曲线 |

页脚：`第 3–4 页 / 共 128 页`。

### 2.3 分页

- 与左页阅读排版一致：主题字号、行距、段距、页边距。
- 使用 TextKit（`NSLayoutManager`）按页面内容区尺寸切页。
- 窗口或字号变化时重新分页，尽量保持当前 spread 起始页不变。

### 2.4 进度

- 按文件路径持久化 `readingSpreadIndex`（`UserDefaults`）。
- 再次进入阅读模式时恢复上次 spread。

---

## 3. 架构

```
ReadingViewModel
├── experienceMode: .learning | .reading
├── readingPageTexts: [String]
├── readingSpreadIndex: Int
└── repaginate / turnPage / enter / exit

ContentView
├── 学习模式（现有 openBook）
└── ReadingSpreadView（全屏 overlay，experienceMode == .reading）

BookPaginator
└── paginate(text:pageSize:typography:) -> [String]
```

---

## 4. 文件

| 文件 | 职责 |
|------|------|
| `ReadingExperienceMode.swift` | 模式枚举 |
| `BookPaginator.swift` | TextKit 分页 |
| `ReadingSpreadView.swift` | 全屏双页 + 翻页动画 |
| `ReadingViewModel.swift` | 状态与持久化 |
| `ContentView.swift` | 入口按钮与 overlay |

---

## 5. 非目标（首版）

- 阅读模式内 AI 浮层
- 与学习模式滚动位置双向同步
- EPUB / PDF 原生分页

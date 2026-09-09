# AIBook 风格主题设计

> 文档性质：实现设计（基于当前 `BookTheme` / `BookInterface` 源码）  
> 关联文档：[整体UI文档设计.md](./整体UI文档设计.md) · [整体功能文档设计.md](./整体功能文档设计.md)

---

## 1. 背景与目标

### 1.1 现状

当前 AIBook 的视觉风格由 `BookTheme` 中的**静态常量**驱动：

| 模块 | 文件 | 硬编码内容 |
|------|------|------------|
| 色彩 | `BookTheme.swift` | 皮革棕、宣纸米黄、墨色、金色、朱红等 20+ 色值 |
| 字体 | `BookTheme.swift` | 宋体 SC 四级字号 |
| 装饰 | `BookInterface.swift` | 皮革封面、丝带书签、金线页眉、折页角、纸纹 |
| 组件 | `BookTheme.swift` / `BookToolbarMenu.swift` | 顶栏胶囊按钮、纸面按钮、状态胶囊、下拉菜单 |
| 全局 | `ContentView.swift` | 书桌渐变、台灯光、强制 `.preferredColorScheme(.light)` |

所有用户看到同一套「古典书房」风格，无法在设置中更换。

### 1.2 目标

1. **可切换**：用户在设置中选择预设主题，立即生效（无需重启）。
2. **一致性**：切换后顶栏、书页、按钮、菜单、设置页、进化面板等**全部界面**同步更新。
3. **可扩展**：架构支持后续新增预设主题，乃至导入自定义主题包（JSON）。
4. **不破坏阅读体验**：无论何种主题，长文可读性、选中高亮、对比度均满足 WCAG AA 基准。

### 1.3 非目标（首版不做）

- 逐色自定义调色板（高级用户 DIY）
- 跟随 macOS 系统外观自动切换
- 主题市场 / 在线下载

---

## 2. 设计原则

| 原则 | 说明 |
|------|------|
| **书籍隐喻可保留也可弱化** | 默认主题保持「书桌上的书」；其他主题可简化为「双栏阅读器」或「深色编辑器」，但布局结构不变 |
| **Token 驱动，禁止散落色值** | 视图中只引用语义 Token（如 `style.colors.ink`），不写 `Color(red:0.38,…)` |
| **装饰与色彩解耦** | 丝带、折页、金线等装饰可随主题开关或替换样式，而非与某一配色绑定 |
| **即时预览** | 设置页选中主题后，设置面板自身与主窗口同步预览 |
| **持久化轻量** | 仅存主题 ID（字符串），预设数据内置在 App 中 |

---

## 3. 主题分层架构

### 3.1 概念模型

```
BookStylePreset（预设主题，如「古典书房」）
└── BookStyleTokens（语义 Token 集合）
    ├── colors      色彩
    ├── typography  字体
    ├── metrics     圆角、间距、阴影
    └── ornaments   装饰开关与变体
```

运行时由 `BookStyleManager`（`ObservableObject`）持有当前 `BookStylePreset`，通过 SwiftUI `Environment` 注入全局。

### 3.2 语义色彩 Token

将现有 `BookTheme` 静态色拆为语义分组：

#### 环境层（书桌 / 窗口背景）

| Token | 用途 | 古典书房参考值 |
|-------|------|----------------|
| `deskTop` | 书桌渐变上色 | `#2E2117` |
| `deskBottom` | 书桌渐变下色 | `#140E0A` |
| `deskLampGlow` | 台灯光晕中心色 + 透明度 | 暖黄 35% → 透明 |

#### 装帧层（顶栏 / 封面 / 书脊）

| Token | 用途 |
|-------|------|
| `bindingHighlight` | 皮革/装帧高光（现 `leatherHighlight`） |
| `bindingBase` | 装帧主色（现 `leather`） |
| `bindingShadow` | 装帧暗部（现 `leatherShadow`） |
| `spineLight` / `spineDark` | 书脊渐变 |
| `chromeText` | 顶栏文字（现 `goldSoft`） |
| `chromeAccent` | 顶栏强调色（现 `gold`） |
| `chromeAccentGradient` | 主按钮金色渐变 |

#### 纸面层（左右页）

| Token | 用途 |
|-------|------|
| `pageLeft` | 左页底色 |
| `pageRight` | 右页底色 |
| `pageEdge` | 页边 / 分隔线 |
| `paperTextureOpacity` | 纸纹线条透明度（0 = 关闭纸纹） |

#### 文字层

| Token | 用途 |
|-------|------|
| `ink` | 正文主色 |
| `inkSecondary` | 次级文字 |
| `inkMuted` | 注释 / 页脚 |
| `selection` | 文本选中高亮 |
| `destructive` | 危险操作（现 `vermilion`） |
| `success` | 成功 / 就绪（现 `jade`） |

#### 交互层（按钮 / 菜单）

| Token | 用途 |
|-------|------|
| `buttonFill` | 普通按钮底色（顶栏半透白） |
| `buttonFillHover` | 悬停底色 |
| `buttonBorder` | 按钮描边 |
| `buttonBorderHover` | 悬停描边 |
| `buttonProminentText` | 主按钮文字色 |
| `menuPanelFill` | 下拉 Popover 背景（默认同装帧渐变） |

### 3.3 字体 Token

| Token | 默认值 | 说明 |
|-------|--------|------|
| `titleFont` | Songti SC 22pt semibold | 顶栏标题、空页大标题 |
| `labelFont` | Songti SC 13pt medium | 按钮、页眉标签 |
| `bodyFont` | Songti SC 16pt | 右页正文 |
| `captionFont` | Songti SC 12pt | 注释、页脚、顶栏紧凑按钮 |
| `readingFont` | Songti SC 17pt | 左页 NSTextView（NSFont） |
| `readingLineSpacing` | 6pt | 左页行距 |

### 3.4 度量 Token

| Token | 默认值 |
|-------|--------|
| `radiusHeader` | 18 |
| `radiusPage` | 8 |
| `radiusCard` | 12–18 |
| `radiusButton` | Capsule |
| `shadowToolbar` | black 36% / r14 / y8 |
| `shadowPage` | black 50% / r32 / y22 |
| `animationHover` | 0.16s easeOut |

### 3.5 装饰 Token

| Token | 类型 | 说明 |
|-------|------|------|
| `showBookmarkRibbon` | Bool | 书脊丝带 |
| `showPageCornerFold` | Bool | 右下角折页 |
| `showHeaderOrnament` | Bool | 页眉金线菱形 |
| `showPaperTexture` | Bool | 纸纹叠加 |
| `bookmarkColors` | `[Color]` | 丝带渐变（可随主题变色） |
| `ornamentStyle` | Enum | `classic` / `minimal` / `none` |

---

## 4. 预设主题方案

首版内置 **5 套预设**，覆盖不同阅读场景。每套给出核心色板与风格描述；完整 Token 表在实现阶段以 JSON / Swift 常量落地。

### 4.1 古典书房（默认 · `classicStudy`）

> 现有视觉，作为迁移基准，确保零回归。

| 维度 | 描述 |
|------|------|
| 隐喻 | 暖色台灯下的皮革精装书 |
| 桌面 | 深棕木 + 暖黄光晕 |
| 纸页 | 米黄宣纸，左亮右暖 |
| 文字 | 浓墨宋体 |
| 强调 | 金色胶囊按钮 |
| 装饰 | 全开：丝带、折页、金线、纸纹 |
| 色彩模式 | 浅色 |

### 4.2 素笺墨香（`plainInk`）

> 极简纸墨，弱化装帧，突出正文。

| 维度 | 描述 |
|------|------|
| 隐喻 | 素色信纸上的墨迹 |
| 桌面 | 浅灰白渐变（`#F5F3EF` → `#EAE6DE`），无台灯光 |
| 纸页 | 纯白 / 极浅灰，左右页色差缩小 |
| 文字 | 深灰墨（`#2C2C2C`），无纯黑 |
| 强调 | 墨色描边按钮，无主色渐变 |
| 装饰 | 全关 |
| 字体 | 可选 STSong / 系统衬线 |
| 色彩模式 | 浅色 |

### 4.3 深夜灯盏（`nightLamp`）

> 暗色书桌 + 暖光阅读区，适合夜间。

| 维度 | 描述 |
|------|------|
| 隐喻 | 暗室中一盏暖灯照着书 |
| 桌面 | 近黑（`#1A1612`） + 琥珀光晕 |
| 顶栏 | 深褐装帧，文字暖金 |
| 纸页 | 深暖灰（`#2A2520` / `#2E2924`），**非纯黑**以减眼疲劳 |
| 文字 | 暖白（`#E8E0D4`） |
| 强调 | 琥珀色（`#D4A054`） |
| 选中 | 琥珀 30% 透明 |
| 装饰 | 仅纸纹（低透明度），关丝带折页 |
| 色彩模式 | 深色（移除强制 `.light`） |

### 4.4 青简竹简（`bambooScroll`）

> 东方青绿点缀，偏文艺清新。

| 维度 | 描述 |
|------|------|
| 隐喻 | 竹简与绢帛 |
| 桌面 | 淡青灰（`#E8EDE8` → `#D6DDD6`） |
| 装帧 | 竹青（`#3D5C48`）替代皮革棕 |
| 纸页 | 绢白微绿 |
| 文字 | 墨绿黑 |
| 强调 | 竹青 + 淡金点缀 |
| 装饰 | 简约页眉线，无丝带 |
| 色彩模式 | 浅色 |

### 4.5 现代简约（`modernClean`）

> 扁平现代 UI，弱书籍隐喻，强信息密度。

| 维度 | 描述 |
|------|------|
| 隐喻 | 双栏 IDE / 笔记应用 |
| 桌面 | 系统灰（`#F0F0F0`） |
| 顶栏 | 白底 + 细边框，文字深灰 |
| 纸页 | 纯白，1px 分隔线 |
| 文字 | SF Pro / 系统无衬线 |
| 强调 | 系统蓝（`#007AFF`） |
| 按钮 | 圆角矩形（非胶囊），无渐变阴影 |
| 装饰 | 全关 |
| 色彩模式 | 浅色 |

### 4.6 预设对比一览

| 主题 ID | 名称 | 模式 | 装饰 | 字体 | 适合场景 |
|---------|------|------|------|------|----------|
| `classicStudy` | 古典书房 | 浅 | 丰富 | 宋体 | 默认、沉浸阅读 |
| `plainInk` | 素笺墨香 | 浅 | 无 | 宋体 | 长文专注 |
| `nightLamp` | 深夜灯盏 | 深 | 极少 | 宋体 | 夜间阅读 |
| `bambooScroll` | 青简竹简 | 浅 | 简约 | 宋体 | 文艺、古籍 |
| `modernClean` | 现代简约 | 浅 | 无 | 系统 | 效率、开发 |

---

## 5. 设置入口与交互设计

### 5.1 入口位置

在 **book 设置**（`BookSettingsView`）中新增第三个 Tab：

```
book 设置
├── AI模型设置
├── 语音设置
└── 外观风格    ← 新增
```

顶栏「book设置」菜单中无需重复入口，保持单一设置路径。

### 5.2 外观设置页布局

```
┌─────────────────────────────────────────────────────┐
│  🎨 外观风格                                         │
│  切换书桌、纸页与按钮的视觉主题                        │
├─────────────────────────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐ ┌─────────┐               │
│  │ 预览缩略 │ │ 预览缩略 │ │ 预览缩略 │  …横向滚动   │
│  │ 古典书房 │ │ 素笺墨香 │ │ 深夜灯盏 │               │
│  │  ✓ 当前  │ │         │ │         │               │
│  └─────────┘ └─────────┘ └─────────┘               │
├─────────────────────────────────────────────────────┤
│  主题名称：古典书房                                   │
│  简介：暖色台灯下的皮革精装书，默认风格                  │
│                                                     │
│  [ 装饰细节 ]                                        │
│  ☑ 书脊丝带   ☑ 折页角   ☑ 纸纹   ☑ 页眉金线         │
│  （仅当当前主题允许覆盖时显示；预设主题有默认值，        │
│    用户微调写入 UserDefaults 独立 key）               │
├─────────────────────────────────────────────────────┤
│  左页字号  [ 15 ▾  16  17  18  19 ]                  │
│  （全局 readingFont 覆盖，可选，默认跟随主题）          │
└─────────────────────────────────────────────────────┘
```

### 5.3 交互规则

| 操作 | 行为 |
|------|------|
| 点击预设卡片 | 立即切换主题，主窗口实时刷新 |
| 当前主题 | 卡片描金边 +「当前」角标 |
| 装饰开关 | 覆盖当前主题的 `ornaments` 子集，不影响色彩 |
| 左页字号 | 覆盖 `readingFont` 字号，主题切换时保留 |
| 关闭设置 | 无需确认，已自动持久化 |

### 5.4 缩略图预览规格

每张卡片 160×100pt，渲染简化版：

- 上 30%：装帧色条（顶栏）
- 中 50%：左右纸色分栏
- 下 20%：按钮色胶囊 × 2

用真实 Token 绘制，保证预览与实机一致。

---

## 6. 技术实现方案

### 6.1 核心类型（建议新增文件）

```
Sources/AIBook/UI/Style/
├── BookStylePreset.swift      // 预设枚举 + 元数据
├── BookStyleTokens.swift      // Token 结构体
├── BookStyleCatalog.swift     // 内置 5 套预设数据
├── BookStyleManager.swift     // ObservableObject，读写 UserDefaults
└── BookStyleEnvironment.swift // EnvironmentKey + View 扩展
```

### 6.2 BookStyleManager

```swift
@MainActor
final class BookStyleManager: ObservableObject {
    static let shared = BookStyleManager()

    @Published var presetID: BookStylePresetID {
        didSet { UserDefaults.standard.set(presetID.rawValue, forKey: Keys.presetID) }
    }

    @Published var ornamentOverrides: OrnamentOverrides { … }

    var tokens: BookStyleTokens {
        BookStyleCatalog.tokens(for: presetID, overrides: ornamentOverrides)
    }

    var colorScheme: ColorScheme? { tokens.preferredColorScheme }
}
```

持久化 Key：

| Key | 类型 | 默认 |
|-----|------|------|
| `bookStyle.presetID` | String | `classicStudy` |
| `bookStyle.ornament.bookmark` | Bool? | nil（跟随预设） |
| `bookStyle.ornament.cornerFold` | Bool? | nil |
| `bookStyle.ornament.paperTexture` | Bool? | nil |
| `bookStyle.ornament.headerOrnament` | Bool? | nil |
| `bookStyle.readingFontSize` | Double? | nil |

### 6.3 Environment 注入

```swift
// AIBookApp.swift
ContentView()
    .environmentObject(BookStyleManager.shared)
    .environment(\.bookStyle, BookStyleManager.shared.tokens)
    .preferredColorScheme(BookStyleManager.shared.colorScheme)

// 视图内使用
@Environment(\.bookStyle) private var style
…
.foregroundStyle(style.colors.ink)
```

### 6.4 BookTheme 迁移策略

**阶段一（兼容层）**：`BookTheme` 保留，内部转发到 `BookStyleManager.shared.tokens`，现有视图零改动即可跑通。

```swift
enum BookTheme {
    static var ink: Color { BookStyleManager.shared.tokens.colors.ink }
    // …
}
```

**阶段二（逐步替换）**：新代码使用 `@Environment(\.bookStyle)`；旧代码逐文件替换 `BookTheme.xxx`。

**阶段三（清理）**：删除 `BookTheme` 静态常量，仅保留 `BookPageStyle` 等依赖 Token 的 ViewModifier。

### 6.5 组件改造清单

| 组件 | 改造要点 |
|------|----------|
| `BookToolbarCapsuleLabel` | 读取 `style.colors.button*` |
| `BookToolbarMenuPanel` | 背景用 `style.colors.menuPanelFill` |
| `BookActionButton` | prominent 渐变用 `chromeAccentGradient` |
| `BookPageButtonStyle` | 纸面按钮色 |
| `BookStatusPill` | 顶栏胶囊 |
| `BookInterface.SpreadShell` | 装帧渐变 |
| `BookInterface.BookmarkRibbon` | 受 `showBookmarkRibbon` 控制 |
| `BookInterface.PaperTexture` | 受 `showPaperTexture` + 透明度控制 |
| `SelectableTextView` | `readingFont` + `selection` 色传入 |
| `BookSettingsView` / `SettingsView` | 设置页自身也走 Token |
| `ContentView` | 移除硬编码 `.preferredColorScheme(.light)` |

### 6.6 NSTextView 与 SwiftUI 同步

左页 `SelectableTextView` 需在主题变更时：

1. 更新 `font`（NSFont from tokens）
2. 更新 `textColor` / `insertionPointColor`
3. 更新选中背景色（`selectedTextAttributes`）

通过 `BookStyleManager` 的 `objectWillChange` 通知 `SelectableTextView` 刷新。

---

## 7. 数据格式（预留自定义主题）

首版仅内置预设；架构预留 JSON 导入：

```json
{
  "id": "user-custom-01",
  "name": "我的主题",
  "version": 1,
  "colors": {
    "deskTop": "#2E2117",
    "ink": "#2C1810",
    …
  },
  "typography": {
    "titleFontName": "Songti SC",
    "titleFontSize": 22
  },
  "ornaments": {
    "showBookmarkRibbon": false
  },
  "preferredColorScheme": "light"
}
```

文件放置：`~/Library/Application Support/ai-book/Styles/*.json`  
设置页「导入主题…」按钮在 **v2** 启用。

---

## 8. 实现分期

### P0 — 能切换（约 2–3 天）

- [ ] `BookStyleTokens` + `BookStyleCatalog`（5 套预设数据）
- [ ] `BookStyleManager` + UserDefaults 持久化
- [ ] `BookTheme` 兼容转发层
- [ ] `BookSettingsView` 新增「外观风格」Tab + 预设卡片选择
- [ ] `ContentView` 响应 `preferredColorScheme`
- [ ] `SelectableTextView` 跟随主题更新字体/颜色

### P1 — 打磨（约 1–2 天）

- [ ] 装饰开关覆盖（丝带 / 折页 / 纸纹 / 页眉）
- [ ] 左页字号调节
- [ ] 预设缩略图预览组件
- [ ] 深夜灯盏主题对比度实测与微调

### P2 — 扩展（后续）

- [ ] JSON 主题导入
- [ ] 导出当前覆盖为 JSON
- [ ] 跟随系统自动浅色/深色
- [ ] 主题切换过渡动画（交叉淡入 0.25s）

---

## 9. 测试要点

| 场景 | 预期 |
|------|------|
| 切换每个预设 | 顶栏、左右页、按钮、菜单、设置页同步变色 |
| 切换后重启 App | 保持上次所选主题 |
| 深夜灯盏 + 长文阅读 30 分钟 | 眼疲劳可接受，对比度 ≥ 4.5:1 |
| 进化面板 / 聊天气泡 | 跟随纸面色与墨色，无残留旧色 |
| 朗读播控顶栏 | 胶囊按钮随 chrome 色更新 |
| 空页欢迎 / 折页 / 丝带 | 装饰开关生效 |
| 左页选中文字 | 高亮色随 `selection` Token 变 |

---

## 10. 与现有文档的关系

| 文档 | 关系 |
|------|------|
| `整体UI文档设计.md` §1.2 | 本章将其中「设计系统（BookTheme）」扩展为可切换主题体系；默认主题与该节描述一致 |
| `整体UI文档设计.md` §1.3 | 「强制浅色模式」将在多主题后改为按主题 `preferredColorScheme` 决定 |
| `aibook进化设计.md` | 无直接冲突；进化面板 UI 同样走 Token |

---

## 11. 总结

AIBook 风格体系从「单一硬编码 `BookTheme`」升级为「**预设主题 + 语义 Token + 设置页切换**」。默认「古典书房」与现网视觉完全一致；新增素笺、深夜、青简、现代四套满足不同阅读偏好。实现上通过 `BookStyleManager` + `Environment` 注入，以兼容层平滑迁移，首版聚焦预设切换与装饰微调，自定义主题导入留作后续扩展。

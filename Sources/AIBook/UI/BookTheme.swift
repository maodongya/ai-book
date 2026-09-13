import AppKit
import SwiftUI

/// 当前风格令牌的快捷入口。视图应读这里，不要自己拼色。
enum BookTheme {
    /// 必须在主线程读 Manager；后台线程调这里会崩。
    static var tokens: BookStyleTokens {
        MainActor.assumeIsolated { BookStyleManager.shared.tokens } // View body 已在主线程
    }

    static var deskTop: Color { tokens.colors.deskTop } // 书桌渐变上沿
    static var deskBottom: Color { tokens.colors.deskBottom }

    static var leather: Color { tokens.colors.bindingBase } // 封面皮，旧名保留给调用方
    static var leatherHighlight: Color { tokens.colors.bindingHighlight }
    static var leatherShadow: Color { tokens.colors.bindingShadow }

    static var pageLeft: Color { tokens.colors.pageLeft }
    static var pageRight: Color { tokens.colors.pageRight }
    static var pageEdge: Color { tokens.colors.pageEdge }

    static var ink: Color { tokens.colors.ink }
    static var inkSecondary: Color { tokens.colors.inkSecondary }
    static var inkMuted: Color { tokens.colors.inkMuted }

    static var gold: Color { tokens.colors.chromeAccent } // 旧调用仍写 gold，实际跟当前强调色
    static var goldSoft: Color { tokens.colors.chromeText }
    static var selection: Color { tokens.colors.selection }
    static var vermilion: Color { tokens.colors.destructive } // 删除/危险
    static var jade: Color { tokens.colors.success } // 成功/就绪

    static var spineLight: Color { tokens.colors.spineLight }
    static var spineDark: Color { tokens.colors.spineDark }

    static var chromeMuted: Color { tokens.colors.chromeMuted }
    static var chromeOverlay: Color { tokens.colors.chromeOverlay }
    static var buttonFill: Color { tokens.colors.buttonFill }
    static var buttonFillHover: Color { tokens.colors.buttonFillHover }
    static var buttonBorder: Color { tokens.colors.buttonBorder }
    static var buttonBorderHover: Color { tokens.colors.buttonBorderHover }
    static var buttonProminentText: Color { tokens.colors.buttonProminentText }
    static var menuPanelFill: Color { tokens.colors.menuPanelFill }
    static var menuPanelBorder: Color { tokens.colors.menuPanelBorder }
    static var menuItemFill: Color { tokens.colors.menuItemFill }
    static var menuItemFillHover: Color { tokens.colors.menuItemFillHover }
    static var menuItemBorder: Color { tokens.colors.menuItemBorder }
    static var menuItemBorderHover: Color { tokens.colors.menuItemBorderHover }
    static var menuItemText: Color { tokens.colors.menuItemText }
    static var menuDivider: Color { tokens.colors.menuDivider }

    static var deskGradient: LinearGradient { tokens.deskGradient }
    static var leatherGradient: LinearGradient { tokens.bindingGradient }
    static var goldGradient: LinearGradient { tokens.accentGradient }

    static var readingFont: NSFont { tokens.typography.readingNSFont }
    static var readingContentFont: Font { tokens.typography.readingFont }
    static var readingLineSpacing: CGFloat { tokens.typography.readingLineSpacing }
    static var titleFont: Font { tokens.typography.titleFont }
    static var labelFont: Font { tokens.typography.labelFont }
    static var bodyFont: Font { tokens.typography.bodyFont }
    static var captionFont: Font { tokens.typography.captionFont }

    static var deskLampGlow: RadialGradient { tokens.deskLampGlow }

    static var showBookmarkRibbon: Bool { tokens.ornaments.showBookmarkRibbon }
    static var showPageCornerFold: Bool { tokens.ornaments.showPageCornerFold }
    static var showHeaderOrnament: Bool { tokens.ornaments.showHeaderOrnament }
    static var showPaperTexture: Bool { tokens.ornaments.showPaperTexture }
    static var paperTextureOpacity: Double { tokens.colors.paperTextureOpacity }
    static var settingsPrimary: Color { tokens.colors.ink } // 设置页主字，跟正文墨色走
    static var settingsSecondary: Color { tokens.colors.inkSecondary }
}

/// 设置窗固定尺寸：按 11 寸 iPad 横屏能放下，再卡在 mini 横屏高度内。
/// and stay within iPad mini landscape height (~744) after sheet chrome.
enum BookSettingsWindowMetrics {
    static let width: CGFloat = 720 // 再宽会超出 mini 安全区
    static let height: CGFloat = 600 // 扣掉 sheet 铬条后仍低于 744
}

/// 书页纸面：底色 + 斜向高光 + 左右书口细线。
struct BookPageStyle: ViewModifier {
    let tint: Color // 左页/右页不同，由调用方传入

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    tint
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.clear,
                            Color.black.opacity(0.04),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(BookTheme.pageEdge.opacity(0.55))
                    .frame(width: 1)
            }
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(BookTheme.pageEdge.opacity(0.35))
                    .frame(width: 1)
            }
    }
}

extension View {
    /// 缺省左页色。右页请显式传 pageRight。
    func bookPage(_ tint: Color? = nil) -> some View {
        modifier(BookPageStyle(tint: tint ?? BookTheme.pageLeft))
    }
}

/// 顶栏「更多」胶囊，弹出 BookToolbarMenuPanel。
struct BookToolbarMenuButton<MenuContent: View>: View {
    var title: String? // nil 时用 action.more
    var isDisabled: Bool = false // 禁用仍占位，避免工具条跳
    @ViewBuilder let menuContent: () -> MenuContent
    @ObservedObject private var styleManager = BookStyleManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var isHovering = false
    @State private var isPresented = false

    var body: some View {
        let _ = settings.localizationRevision // 换语言时重读默认标题
        let resolvedTitle = title ?? BookL10n.string("action.more")
        Button {
            isPresented.toggle() // 再点一次关，不另做外侧点空白
        } label: {
            BookToolbarCapsuleLabel(
                title: resolvedTitle,
                isProminent: false,
                isCompact: true,
                isHovering: isHovering
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .fixedSize()
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            BookToolbarMenuPanel(isPresented: $isPresented) {
                menuContent()
            }
            .bookStyleEnvironment(styleManager)
        }
        .id("menu-\(resolvedTitle)-\(styleManager.revision)-\(settings.localizationRevision)")
    }
}

/// 顶栏动作胶囊。有 icon 走 Label，没有走纯文字胶囊。
struct BookActionButton: View {
    let title: String
    var icon: String?
    var isProminent: Bool = false
    var isCompact: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void // 调用方负责关窗/导航
    @ObservedObject private var styleManager = BookStyleManager.shared
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if let icon {
                    Label(title, systemImage: icon)
                        .font(isCompact ? styleManager.tokens.typography.captionFont : styleManager.tokens.typography.labelFont)
                        .foregroundStyle(isProminent ? styleManager.tokens.colors.buttonProminentText : styleManager.tokens.colors.chromeText)
                        .padding(.horizontal, isCompact ? 10 : 13)
                        .padding(.vertical, isCompact ? 5 : 8)
                        .background {
                            BookToolbarCapsuleBackground(isProminent: isProminent, isHovering: isHovering)
                        }
                } else {
                    BookToolbarCapsuleLabel(
                        title: title,
                        isProminent: isProminent,
                        isCompact: isCompact,
                        isHovering: isHovering
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .id("action-\(title)-\(isProminent)-\(styleManager.revision)")
    }
}

/// 右页（浅色纸面）操作按钮，与顶栏 `BookActionButton` 同系胶囊样式。
struct BookPageActionButton: View {
    let title: String
    let icon: String
    var isProminent: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
        .bookPageButton(prominent: isProminent)
        .disabled(isDisabled)
    }
}

/// 右页浅色纸面上的胶囊：非强调走半透明纸色，避免跟顶栏皮色撞。
struct BookPageButtonStyle: ViewModifier {
    var isProminent: Bool = false
    @Environment(\.isEnabled) private var isEnabled
    @ObservedObject private var styleManager = BookStyleManager.shared
    @State private var isHovering = false

    func body(content: Content) -> some View {
        let tokens = styleManager.tokens
        content
            .buttonStyle(.plain)
            .font(tokens.typography.labelFont)
            .foregroundStyle(isProminent ? tokens.colors.buttonProminentText : tokens.colors.bindingBase)
            .lineLimit(1)
            .padding(.horizontal, isProminent ? 14 : 12)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(
                        isProminent
                            ? AnyShapeStyle(tokens.accentGradient)
                            : AnyShapeStyle(tokens.colors.pageLeft.opacity(isHovering ? 0.95 : 0.82))
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                isProminent
                                    ? tokens.colors.chromeText.opacity(0.70)
                                    : tokens.colors.pageEdge.opacity(isHovering ? 0.95 : 0.80),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: isProminent
                            ? tokens.colors.chromeAccent.opacity(0.22)
                            : .black.opacity(isHovering ? 0.10 : 0.05),
                        radius: isHovering ? 6 : 3,
                        y: isHovering ? 3 : 1
                    )
            }
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.16), value: isHovering)
            .id(styleManager.revision)
    }
}

extension View {
    /// 页内按钮修饰。
    func bookPageButton(prominent: Bool = false) -> some View {
        modifier(BookPageButtonStyle(isProminent: prominent))
    }
}

/// 顶栏状态小胶囊，只展示不点击。
struct BookStatusPill: View {
    let title: String
    var icon: String?
    var tint: Color? = nil // nil 跟铬字色，成功/失败由调用方着色
    @ObservedObject private var styleManager = BookStyleManager.shared

    var body: some View {
        let colors = styleManager.tokens.colors
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(title)
        }
        .font(styleManager.tokens.typography.captionFont)
        .foregroundStyle(tint ?? colors.chromeText)
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(colors.chromeOverlay.opacity(0.075))
                .overlay {
                    Capsule()
                        .strokeBorder(colors.chromeOverlay.opacity(0.10), lineWidth: 1)
                }
        }
        .id(styleManager.revision)
    }
}

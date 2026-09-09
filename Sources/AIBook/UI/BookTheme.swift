import AppKit
import SwiftUI

enum BookTheme {
    static var tokens: BookStyleTokens {
        MainActor.assumeIsolated { BookStyleManager.shared.tokens }
    }

    static var deskTop: Color { tokens.colors.deskTop }
    static var deskBottom: Color { tokens.colors.deskBottom }

    static var leather: Color { tokens.colors.bindingBase }
    static var leatherHighlight: Color { tokens.colors.bindingHighlight }
    static var leatherShadow: Color { tokens.colors.bindingShadow }

    static var pageLeft: Color { tokens.colors.pageLeft }
    static var pageRight: Color { tokens.colors.pageRight }
    static var pageEdge: Color { tokens.colors.pageEdge }

    static var ink: Color { tokens.colors.ink }
    static var inkSecondary: Color { tokens.colors.inkSecondary }
    static var inkMuted: Color { tokens.colors.inkMuted }

    static var gold: Color { tokens.colors.chromeAccent }
    static var goldSoft: Color { tokens.colors.chromeText }
    static var selection: Color { tokens.colors.selection }
    static var vermilion: Color { tokens.colors.destructive }
    static var jade: Color { tokens.colors.success }

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
    static var settingsPrimary: Color { tokens.colors.ink }
    static var settingsSecondary: Color { tokens.colors.inkSecondary }
}

/// Fixed settings chrome. Sized to fit an 11-inch iPad landscape (~1194×834)
/// and stay within iPad mini landscape height (~744) after sheet chrome.
enum BookSettingsWindowMetrics {
    static let width: CGFloat = 720
    static let height: CGFloat = 600
}

struct BookPageStyle: ViewModifier {
    let tint: Color

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
    func bookPage(_ tint: Color? = nil) -> some View {
        modifier(BookPageStyle(tint: tint ?? BookTheme.pageLeft))
    }
}

struct BookToolbarMenuButton<MenuContent: View>: View {
    var title: String = "更多"
    var isDisabled: Bool = false
    @ViewBuilder let menuContent: () -> MenuContent
    @ObservedObject private var styleManager = BookStyleManager.shared
    @State private var isHovering = false
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            BookToolbarCapsuleLabel(
                title: title,
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
        .id("menu-\(title)-\(styleManager.revision)")
    }
}

struct BookActionButton: View {
    let title: String
    var icon: String?
    var isProminent: Bool = false
    var isCompact: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
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
    func bookPageButton(prominent: Bool = false) -> some View {
        modifier(BookPageButtonStyle(isProminent: prominent))
    }
}

struct BookStatusPill: View {
    let title: String
    var icon: String?
    var tint: Color? = nil
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

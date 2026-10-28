import SwiftUI

// MARK: - Shared capsule chrome (toolbar buttons + menu items)

/// 顶栏胶囊底：主按钮走强调渐变，普通按钮 hover 加深描边。
struct BookToolbarCapsuleBackground: View {
    var isProminent: Bool = false // 完成/主操作走金底
    var isHovering: Bool = false // 由外层 onHover 传入，本视图不自己侦测
    @ObservedObject private var styleManager = BookStyleManager.shared

    var body: some View {
        let colors = styleManager.tokens.colors
        Capsule()
            .fill(
                isProminent
                    ? AnyShapeStyle(styleManager.tokens.accentGradient)
                    : AnyShapeStyle(isHovering ? colors.buttonFillHover : colors.buttonFill)
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        isProminent
                            ? colors.chromeText.opacity(0.85)
                            : (isHovering ? colors.buttonBorderHover : colors.buttonBorder),
                        lineWidth: 1.2
                    )
            }
            .shadow(
                color: isProminent
                    ? colors.chromeAccent.opacity(0.25)
                    : .black.opacity(isHovering ? 0.18 : 0.08),
                radius: isHovering ? 8 : 4,
                y: isHovering ? 4 : 2
            )
    }
}

/// 顶栏胶囊文字。compact 给工具条，宽松给页内。
struct BookToolbarCapsuleLabel: View {
    let title: String // 已本地化文案，这里不再查表
    var isProminent: Bool = false
    var isCompact: Bool = true // 顶栏挤，页内可拉开
    var isHovering: Bool = false
    @ObservedObject private var styleManager = BookStyleManager.shared

    var body: some View {
        let tokens = styleManager.tokens
        Text(title)
            .font(isCompact ? tokens.typography.captionFont : tokens.typography.labelFont)
            .foregroundStyle(isProminent ? tokens.colors.buttonProminentText : tokens.colors.chromeText)
            .lineLimit(1)
            .padding(.horizontal, isCompact ? (isProminent ? 12 : 10) : (isProminent ? 16 : 13))
            .padding(.vertical, isCompact ? 5 : 8)
            .background {
                BookToolbarCapsuleBackground(isProminent: isProminent, isHovering: isHovering)
            }
    }
}

// MARK: - Custom popover menu (matches toolbar button style)

/// 菜单项点完后关 popover，由面板注入。
private struct BookToolbarMenuDismissKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// 点菜单项后关浮层；没注入则只触发 action。
    var bookToolbarMenuDismiss: (() -> Void)? {
        get { self[BookToolbarMenuDismissKey.self] }
        set { self[BookToolbarMenuDismissKey.self] = newValue }
    }
}

/// 溢出菜单面板。点项后通过 environment 关 isPresented。
struct BookToolbarMenuPanel<Content: View>: View {
    @Binding var isPresented: Bool // 面板自己也能关，不只靠外层按钮
    @ViewBuilder var content: () -> Content
    @ObservedObject private var styleManager = BookStyleManager.shared

    var body: some View {
        let colors = styleManager.tokens.colors
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(10)
        .frame(minWidth: 188)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colors.menuPanelFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(colors.menuPanelBorder, lineWidth: 1.2)
                }
                .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
        }
        .buttonStyle(BookToolbarMenuItemButtonStyle())
        .environment(\.bookToolbarMenuDismiss, { isPresented = false }) // 子项点完立刻收起
        .preferredColorScheme(styleManager.colorScheme)
        .id(styleManager.revision)
    }
}

/// 菜单行胶囊底，hover 换填色。
struct BookMenuItemCapsuleBackground: View {
    var isHovering: Bool = false
    @ObservedObject private var styleManager = BookStyleManager.shared

    var body: some View {
        let colors = styleManager.tokens.colors
        Capsule()
            .fill(isHovering ? colors.menuItemFillHover : colors.menuItemFill)
            .overlay {
                Capsule()
                    .strokeBorder(
                        isHovering ? colors.menuItemBorderHover : colors.menuItemBorder,
                        lineWidth: 1
                    )
            }
    }
}

/// 菜单项：触发后顺手 dismiss，destructive 走朱红。
struct BookToolbarMenuItemButtonStyle: PrimitiveButtonStyle {
    /// 交给内部 View 才能用 hover / environment。
    func makeBody(configuration: Configuration) -> some View {
        BookToolbarMenuItemButton(configuration: configuration)
    }
}

/// PrimitiveButton 的实际行：先 trigger 再关菜单。
private struct BookToolbarMenuItemButton: View {
    let configuration: PrimitiveButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.bookToolbarMenuDismiss) private var dismissMenu
    @ObservedObject private var styleManager = BookStyleManager.shared
    @State private var isHovering = false

    var body: some View {
        let colors = styleManager.tokens.colors
        Button {
            configuration.trigger() // 先做事再关，避免关窗打断 action
            dismissMenu?() // 没注入时只做事，给嵌套预览用
        } label: {
            configuration.label
                .font(styleManager.tokens.typography.captionFont.weight(.medium))
                .foregroundStyle(configuration.role == .destructive ? colors.destructive : colors.menuItemText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    BookMenuItemCapsuleBackground(isHovering: isHovering)
                }
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.42)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
    }
}

/// 子菜单标题行，右侧 › 表示可展开，本身不关浮层。
struct BookToolbarSubmenuHeaderButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BookToolbarSubmenuHeaderButton(configuration: configuration)
    }
}

/// 子菜单标题的 hover 行。
private struct BookToolbarSubmenuHeaderButton: View {
    let configuration: PrimitiveButtonStyleConfiguration
    @ObservedObject private var styleManager = BookStyleManager.shared
    @State private var isHovering = false

    var body: some View {
        let colors = styleManager.tokens.colors
        Button(action: configuration.trigger) {
            HStack(spacing: 6) {
                configuration.label
                    .font(styleManager.tokens.typography.captionFont.weight(.medium))
                    .foregroundStyle(colors.menuItemText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("›")
                    .font(styleManager.tokens.typography.captionFont.weight(.semibold))
                    .foregroundStyle(colors.menuItemText.opacity(0.55))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                BookMenuItemCapsuleBackground(isHovering: isHovering)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
    }
}

/// 语言多选行。点选只改勾选，不关闭菜单，方便一次勾上或取消多种。
struct BookToolbarMenuCheckbox: View {
    let title: String
    let isOn: Bool
    var isEnabled: Bool = true
    let action: () -> Void
    @ObservedObject private var styleManager = BookStyleManager.shared
    @State private var isHovering = false

    var body: some View {
        let colors = styleManager.tokens.colors
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isOn ? colors.chromeAccent : colors.menuItemText.opacity(0.72))
                Text(title)
                    .font(styleManager.tokens.typography.captionFont.weight(.medium))
                    .foregroundStyle(colors.menuItemText)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                BookMenuItemCapsuleBackground(isHovering: isHovering && isEnabled)
            }
        }
        .buttonStyle(.plain) // 不用会关闭菜单的那套按钮样式
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
    }
}

/// 菜单分组细线。
struct BookToolbarMenuDivider: View {
    @ObservedObject private var styleManager = BookStyleManager.shared

    var body: some View {
        Rectangle()
            .fill(styleManager.tokens.colors.menuDivider)
            .frame(height: 1)
            .padding(.vertical, 3)
            .padding(.horizontal, 4)
    }
}

/// 菜单里不可点的说明行。
struct BookToolbarMenuCaption: View {
    let title: String
    @ObservedObject private var styleManager = BookStyleManager.shared

    var body: some View {
        Text(title)
            .font(styleManager.tokens.typography.captionFont)
            .foregroundStyle(styleManager.tokens.colors.menuItemText.opacity(0.62))
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }
}

/// 溢出菜单中的可展开子菜单，子项沿用顶栏胶囊按钮样式。
struct BookToolbarSubmenu<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @State private var isExpanded = false // 默认收起，避免溢出菜单又高又挤

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeOut(duration: 0.16)) {
                    isExpanded.toggle()
                }
            } label: {
                Text(title)
            }
            .buttonStyle(BookToolbarSubmenuHeaderButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    content()
                }
                .padding(.leading, 6)
            }
        }
    }
}

import SwiftUI

// MARK: - Shared capsule chrome (toolbar buttons + menu items)

struct BookToolbarCapsuleBackground: View {
    var isProminent: Bool = false
    var isHovering: Bool = false
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

struct BookToolbarCapsuleLabel: View {
    let title: String
    var isProminent: Bool = false
    var isCompact: Bool = true
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

private struct BookToolbarMenuDismissKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var bookToolbarMenuDismiss: (() -> Void)? {
        get { self[BookToolbarMenuDismissKey.self] }
        set { self[BookToolbarMenuDismissKey.self] = newValue }
    }
}

struct BookToolbarMenuPanel<Content: View>: View {
    @Binding var isPresented: Bool
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
        .environment(\.bookToolbarMenuDismiss, { isPresented = false })
        .preferredColorScheme(styleManager.colorScheme)
        .id(styleManager.revision)
    }
}

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

struct BookToolbarMenuItemButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BookToolbarMenuItemButton(configuration: configuration)
    }
}

private struct BookToolbarMenuItemButton: View {
    let configuration: PrimitiveButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.bookToolbarMenuDismiss) private var dismissMenu
    @ObservedObject private var styleManager = BookStyleManager.shared
    @State private var isHovering = false

    var body: some View {
        let colors = styleManager.tokens.colors
        Button {
            configuration.trigger()
            dismissMenu?()
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

struct BookToolbarSubmenuHeaderButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BookToolbarSubmenuHeaderButton(configuration: configuration)
    }
}

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
    @State private var isExpanded = false

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

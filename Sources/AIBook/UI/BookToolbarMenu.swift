import SwiftUI

// MARK: - Shared capsule chrome (toolbar buttons + menu items)

struct BookToolbarCapsuleBackground: View {
    var isProminent: Bool = false
    var isHovering: Bool = false

    var body: some View {
        Capsule()
            .fill(
                isProminent
                    ? AnyShapeStyle(BookTheme.goldGradient)
                    : AnyShapeStyle(Color.white.opacity(isHovering ? 0.14 : 0.08))
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        isProminent
                            ? BookTheme.goldSoft.opacity(0.75)
                            : Color.white.opacity(isHovering ? 0.22 : 0.12),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: isProminent
                    ? BookTheme.gold.opacity(0.25)
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

    var body: some View {
        Text(title)
            .font(isCompact ? BookTheme.captionFont : BookTheme.labelFont)
            .foregroundStyle(isProminent ? BookTheme.leatherShadow : BookTheme.goldSoft)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(10)
        .frame(minWidth: 168)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BookTheme.leatherGradient)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
        }
        .buttonStyle(BookToolbarMenuItemButtonStyle())
        .environment(\.bookToolbarMenuDismiss, { isPresented = false })
    }
}

struct BookToolbarMenuItemButtonStyle: PrimitiveButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.bookToolbarMenuDismiss) private var dismissMenu
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.trigger()
            dismissMenu?()
        } label: {
            configuration.label
                .font(BookTheme.captionFont)
                .foregroundStyle(foregroundColor(for: configuration.role))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    BookToolbarCapsuleBackground(isProminent: false, isHovering: isHovering)
                }
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
    }

    private func foregroundColor(for role: ButtonRole?) -> Color {
        role == .destructive ? BookTheme.vermilion.opacity(0.92) : BookTheme.goldSoft
    }
}

struct BookToolbarSubmenuHeaderButtonStyle: PrimitiveButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        Button(action: configuration.trigger) {
            HStack(spacing: 6) {
                configuration.label
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.goldSoft)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("›")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                BookToolbarCapsuleBackground(isProminent: false, isHovering: isHovering)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
    }
}

struct BookToolbarMenuDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.14))
            .frame(height: 1)
            .padding(.vertical, 2)
    }
}

struct BookToolbarMenuCaption: View {
    let title: String

    var body: some View {
        Text(title)
            .font(BookTheme.captionFont)
            .foregroundStyle(Color.white.opacity(0.72))
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
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

import AppKit
import SwiftUI

enum BookTheme {
    static let deskTop = Color(red: 0.18, green: 0.13, blue: 0.09)
    static let deskBottom = Color(red: 0.08, green: 0.055, blue: 0.04)

    static let leather = Color(red: 0.38, green: 0.23, blue: 0.15)
    static let leatherHighlight = Color(red: 0.54, green: 0.34, blue: 0.20)
    static let leatherShadow = Color(red: 0.18, green: 0.10, blue: 0.065)

    static let pageLeft = Color(red: 0.99, green: 0.96, blue: 0.89)
    static let pageRight = Color(red: 0.97, green: 0.94, blue: 0.87)
    static let pageEdge = Color(red: 0.86, green: 0.78, blue: 0.66)

    static let ink = Color(red: 0.18, green: 0.14, blue: 0.10)
    static let inkSecondary = Color(red: 0.40, green: 0.34, blue: 0.26)
    static let inkMuted = Color(red: 0.55, green: 0.48, blue: 0.38)

    static let gold = Color(red: 0.82, green: 0.64, blue: 0.30)
    static let goldSoft = Color(red: 0.95, green: 0.86, blue: 0.64)
    static let selection = Color(red: 0.95, green: 0.86, blue: 0.55)
    static let vermilion = Color(red: 0.64, green: 0.16, blue: 0.12)
    static let jade = Color(red: 0.24, green: 0.43, blue: 0.34)

    static let spineLight = Color(red: 0.72, green: 0.62, blue: 0.48)
    static let spineDark = Color(red: 0.48, green: 0.38, blue: 0.26)

    static var deskGradient: LinearGradient {
        LinearGradient(
            colors: [deskTop, deskBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var leatherGradient: LinearGradient {
        LinearGradient(
            colors: [leatherHighlight, leather, leatherShadow],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var goldGradient: LinearGradient {
        LinearGradient(
            colors: [goldSoft, gold, Color(red: 0.68, green: 0.48, blue: 0.20)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var readingFont: NSFont {
        NSFont(name: "Songti SC", size: 17)
            ?? NSFont(name: "STSong", size: 17)
            ?? NSFont(name: "Georgia", size: 17)
            ?? NSFont.systemFont(ofSize: 17)
    }

    static var titleFont: Font {
        .custom("Songti SC", size: 22).weight(.semibold)
    }

    static var labelFont: Font {
        .custom("Songti SC", size: 13).weight(.medium)
    }

    static var bodyFont: Font {
        .custom("Songti SC", size: 16)
    }

    static var captionFont: Font {
        .custom("Songti SC", size: 12)
    }

    /// 台灯暖光，铺在书桌背景上。
    static var deskLampGlow: RadialGradient {
        RadialGradient(
            colors: [
                Color(red: 0.42, green: 0.32, blue: 0.18).opacity(0.35),
                Color.clear,
            ],
            center: .top,
            startRadius: 40,
            endRadius: 420
        )
    }
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
    func bookPage(_ tint: Color = BookTheme.pageLeft) -> some View {
        modifier(BookPageStyle(tint: tint))
    }
}

struct BookToolbarMenuButton<MenuContent: View>: View {
    var title: String = "更多"
    var isDisabled: Bool = false
    @ViewBuilder let menuContent: () -> MenuContent
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
        }
    }
}

struct BookActionButton: View {
    let title: String
    var icon: String?
    var isProminent: Bool = false
    var isCompact: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if let icon {
                    Label(title, systemImage: icon)
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
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .font(BookTheme.labelFont)
            .foregroundStyle(isProminent ? BookTheme.leatherShadow : BookTheme.leather)
            .lineLimit(1)
            .padding(.horizontal, isProminent ? 14 : 12)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(
                        isProminent
                            ? AnyShapeStyle(BookTheme.goldGradient)
                            : AnyShapeStyle(Color.white.opacity(isHovering ? 0.78 : 0.62))
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                isProminent
                                    ? BookTheme.goldSoft.opacity(0.70)
                                    : BookTheme.pageEdge.opacity(isHovering ? 0.85 : 0.68),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: isProminent
                            ? BookTheme.gold.opacity(0.22)
                            : .black.opacity(isHovering ? 0.10 : 0.05),
                        radius: isHovering ? 6 : 3,
                        y: isHovering ? 3 : 1
                    )
            }
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.16), value: isHovering)
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
    var tint: Color = BookTheme.goldSoft

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(title)
        }
        .font(BookTheme.captionFont)
        .foregroundStyle(tint)
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.075))
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
    }
}

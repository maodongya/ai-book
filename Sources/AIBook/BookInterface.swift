import SwiftUI

/// 书籍界面装饰：装帧、纸张纹理、书脊丝带、页角与页码（配合 BookTheme 使用）。
enum BookInterface {
    static let leftPageMark = "— 左页 —"
    static let rightPageMark = "— 右页 —"

    /// 打开的书本外框：皮革封面、内凹书页、投影。
    struct SpreadShell<Content: View>: View {
        @ViewBuilder let content: Content

        var body: some View {
            content
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(BookTheme.leatherGradient)
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(BookTheme.leatherShadow.opacity(0.65))
                            .padding(6)
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.14),
                                        Color.black.opacity(0.12),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .padding(4)
                    }
                }
                .shadow(color: .black.opacity(0.5), radius: 32, y: 22)
        }
    }

    /// 书脊上的丝带书签。
    struct BookmarkRibbon: View {
        var body: some View {
            VStack(spacing: 0) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.82, green: 0.18, blue: 0.14),
                                Color(red: 0.58, green: 0.10, blue: 0.08),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 2)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.75, green: 0.14, blue: 0.10),
                                Color(red: 0.45, green: 0.08, blue: 0.06),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 10, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            }
            .offset(y: -8)
        }
    }

    /// 页眉装饰线（金线 + 菱形）。
    struct HeaderOrnament: View {
        var body: some View {
            HStack(spacing: 8) {
                ornamentLine
                Image(systemName: "diamond.fill")
                    .font(.system(size: 5))
                    .foregroundStyle(BookTheme.gold.opacity(0.85))
                ornamentLine
            }
            .padding(.horizontal, 28)
        }

        private var ornamentLine: some View {
            LinearGradient(
                colors: [
                    BookTheme.pageEdge.opacity(0.1),
                    BookTheme.gold.opacity(0.55),
                    BookTheme.pageEdge.opacity(0.1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
        }
    }

    /// 页脚页码牌。
    struct PageMark: View {
        let label: String

        var body: some View {
            Text(label)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted.opacity(0.75))
                .tracking(2)
        }
    }

    /// 纸张纹理与内缘阴影。
    struct PaperTexture: ViewModifier {
        func body(content: Content) -> some View {
            content
                .overlay {
                    Canvas { context, size in
                        let step: CGFloat = 28
                        var y: CGFloat = 0
                        while y < size.height {
                            let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                            context.fill(
                                Path(rect),
                                with: .color(Color.black.opacity(0.018))
                            )
                            y += step
                        }
                    }
                    .allowsHitTesting(false)
                }
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.04),
                            Color.clear,
                            Color.black.opacity(0.03),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .allowsHitTesting(false)
                }
        }
    }

    /// 右下角折页装饰。
    struct PageCornerFold: View {
        var body: some View {
            GeometryReader { geo in
                Path { path in
                    let w: CGFloat = 36
                    let h: CGFloat = 36
                    path.move(to: CGPoint(x: geo.size.width, y: geo.size.height - h))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: geo.size.width - w, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [BookTheme.pageEdge, BookTheme.pageEdge.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Path { path in
                        let w: CGFloat = 36
                        let h: CGFloat = 36
                        path.move(to: CGPoint(x: geo.size.width - w, y: geo.size.height))
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - h))
                    }
                    .stroke(BookTheme.inkMuted.opacity(0.2), lineWidth: 0.5)
                }
            }
            .frame(width: 36, height: 36)
            .allowsHitTesting(false)
        }
    }

    /// 空页欢迎：翻开的书与引导文案。
    struct EmptyPageWelcome: View {
        let onOpen: () -> Void

        var body: some View {
            VStack(spacing: 22) {
                ZStack {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(BookTheme.leather.opacity(0.35))
                        .offset(x: -6, y: 4)
                    Image(systemName: "text.book.closed.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(BookTheme.gold.opacity(0.7))
                }

                VStack(spacing: 8) {
                    Text("翻开书页")
                        .font(BookTheme.titleFont)
                        .foregroundStyle(BookTheme.ink.opacity(0.65))
                    Text("在此输入命令笔记，或从顶栏「核心功能」新建 / 打开")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted.opacity(0.7))
                    Text("选中文字后点击顶部「讲解」")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted.opacity(0.55))
                }

                Button(action: onOpen) {
                    Label("打开文本文件", systemImage: "folder")
                        .font(BookTheme.labelFont)
                        .foregroundStyle(BookTheme.leatherShadow)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background {
                            Capsule()
                                .fill(BookTheme.gold.opacity(0.88))
                                .shadow(color: BookTheme.gold.opacity(0.35), radius: 6, y: 3)
                        }
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(true)
        }
    }
}

extension View {
    func bookPaperTexture() -> some View {
        modifier(BookInterface.PaperTexture())
    }
}

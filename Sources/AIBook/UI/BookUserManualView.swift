import SwiftUI

struct BookUserManualView: View {
    @ObservedObject private var styleManager = BookStyleManager.shared
    @Environment(\.dismiss) private var dismiss

    private let markdown = BookUserManual.loadMarkdown()

    var body: some View {
        ZStack {
            BookTheme.deskGradient
                .ignoresSafeArea()

            VStack(spacing: 16) {
                header

                ScrollView {
                    VStack(spacing: 0) {
                        BookUserManualMarkdownView(markdown: markdown)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 28)
                    }
                    .frame(maxWidth: 680, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .bookPage(BookTheme.pageLeft)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(BookTheme.gold.opacity(0.16), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
            }
            .padding(24)
        }
        .frame(width: 820, height: 860)
        .id(styleManager.revision)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(BookTheme.chromeOverlay.opacity(0.08))
                    .frame(width: 46, height: 46)
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(BookTheme.goldSoft)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(BookL10n.string("manual.title"))
                    .font(BookTheme.titleFont)
                    .foregroundStyle(BookTheme.goldSoft)
                Text("\(AIBookProduct.displayName) · \(AIBookProduct.tagline)")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.goldSoft.opacity(0.92))
            }

            Spacer()

            BookActionButton(title: BookL10n.string("action.manual.openSystem"), icon: "arrow.up.forward.square") {
                BookUserManual.openInDefaultEditor()
            }

            BookActionButton(title: BookL10n.string("action.done"), icon: "checkmark", isProminent: true) {
                dismiss()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BookTheme.leatherGradient)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(BookTheme.chromeOverlay.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.32), radius: 16, y: 8)
        }
    }
}

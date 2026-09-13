import SwiftUI

/// 翻译进行中弹出层：流式预览与停止，不在讲解区或教案编辑器里展示。
struct TranslationProgressSheet: View {
    @EnvironmentObject private var viewModel: ReadingViewModel
    @ObservedObject private var styleManager = BookStyleManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(viewModel.translation.translationProgressTitle)
                    .font(BookTheme.titleFont)
                    .foregroundStyle(styleManager.tokens.colors.ink)
                Spacer(minLength: 8)
                if viewModel.isRunning {
                    ProgressView().controlSize(.small)
                }
            }

            Text(BookL10n.string("translation.progress.hint"))
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkSecondary)

            ScrollView {
                Group {
                    if viewModel.translation.translationStreamPreview.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text(BookL10n.string("translation.generating"))
                                .font(BookTheme.captionFont)
                                .foregroundStyle(BookTheme.inkSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    } else {
                        Text(viewModel.translation.translationStreamPreview)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(BookTheme.ink)
                            .lineSpacing(BookTheme.readingLineSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.45))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(BookTheme.pageEdge.opacity(0.45), lineWidth: 1)
                    }
            }

            HStack {
                Spacer()
                Button(role: .destructive) {
                    viewModel.stopCurrentRun()
                } label: {
                    Text(BookL10n.string("action.stop"))
                }
                .disabled(!viewModel.isRunning)
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
        .interactiveDismissDisabled(viewModel.isRunning)
        .id(styleManager.revision)
    }
}

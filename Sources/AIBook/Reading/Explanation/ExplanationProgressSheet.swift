import SwiftUI

/// 全文讲解进行中弹出层：固定高度，流式预览自动滚到最新。
struct ExplanationProgressSheet: View {
    @EnvironmentObject private var viewModel: ReadingViewModel
    @ObservedObject private var styleManager = BookStyleManager.shared

    private let popupSize = CGSize(width: 560, height: 440)
    private let streamEndID = "explanation-stream-end"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(viewModel.assistant.explanationProgressTitle)
                    .font(BookTheme.titleFont)
                    .foregroundStyle(styleManager.tokens.colors.ink)
                Spacer(minLength: 8)
                if viewModel.isRunning {
                    ProgressView().controlSize(.small)
                }
            }

            Text(BookL10n.string("explanation.progress.hint"))
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkSecondary)

            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        if viewModel.assistant.explanationStreamPreview.isEmpty {
                            HStack(spacing: 10) {
                                ProgressView().controlSize(.small)
                                Text(BookL10n.string("explanation.generating"))
                                    .font(BookTheme.captionFont)
                                    .foregroundStyle(BookTheme.inkSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        } else {
                            Text(viewModel.assistant.explanationStreamPreview)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(BookTheme.ink)
                                .lineSpacing(BookTheme.readingLineSpacing)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(streamEndID)
                }
                .onChange(of: viewModel.assistant.explanationStreamPreview) { _ in
                    scrollToLatest(proxy: proxy)
                }
                .onAppear {
                    scrollToLatest(proxy: proxy)
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
        .frame(width: popupSize.width, height: popupSize.height)
    }

    private func scrollToLatest(proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.12)) {
                proxy.scrollTo(streamEndID, anchor: .bottom)
            }
        }
    }
}

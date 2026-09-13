import SwiftUI

/// 翻译进行中弹出层：固定高度，流式预览自动滚到最新。
struct TranslationProgressSheet: View {
    @EnvironmentObject private var viewModel: ReadingViewModel
    @ObservedObject private var styleManager = BookStyleManager.shared

    /// 弹出层外框，不随流式文本长高。
    private let popupSize = CGSize(width: 560, height: 440)
    /// 预览底部锚点，scrollTo 用。
    private let streamEndID = "translation-stream-end"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(viewModel.translation.translationProgressTitle)  // 逐字/整段/当前批次
                    .font(BookTheme.titleFont)
                    .foregroundStyle(styleManager.tokens.colors.ink)
                Spacer(minLength: 8)
                if viewModel.isRunning {
                    ProgressView().controlSize(.small)  // 请求中转圈
                }
            }

            Text(BookL10n.string("translation.progress.hint"))  // 说明不进讲解区
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkSecondary)

            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        if viewModel.translation.translationStreamPreview.isEmpty {
                            HStack(spacing: 10) {
                                ProgressView().controlSize(.small)  // 还没流出字
                                Text(BookL10n.string("translation.generating"))
                                    .font(BookTheme.captionFont)
                                    .foregroundStyle(BookTheme.inkSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        } else {
                            Text(viewModel.translation.translationStreamPreview)  // 只在弹出层展示
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(BookTheme.ink)
                                .lineSpacing(BookTheme.readingLineSpacing)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(streamEndID)  // 流式吸底锚点
                }
                .onChange(of: viewModel.translation.translationStreamPreview) { _ in
                    scrollToLatest(proxy: proxy)  // 每段增量跟到底
                }
                .onAppear {
                    scrollToLatest(proxy: proxy)  // 打开时若已有预览也钉底
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)  // 吃掉固定外框里的剩余高度
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
                    viewModel.stopCurrentRun()  // 取消当前翻译
                } label: {
                    Text(BookL10n.string("action.stop"))
                }
                .disabled(!viewModel.isRunning)
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(20)
        .frame(width: popupSize.width, height: popupSize.height)  // 高度固定，内容在内部滚
        .interactiveDismissDisabled(viewModel.isRunning)
        .id(styleManager.revision)
    }

    /// 流式变长后钉在预览底部。
    private func scrollToLatest(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) {  // 短动画，避免跳动
            proxy.scrollTo(streamEndID, anchor: .bottom)  // 钉最新输出
        }
    }
}

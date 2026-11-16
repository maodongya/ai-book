import AppKit
import SwiftUI

/// 右页讲解 / 进化对话区：消息列表与流式输出，不含输入框。
struct ExplanationChatTranscriptView: View {
    @EnvironmentObject private var viewModel: ReadingViewModel  // 消息、流式、右页 tab 都从这读
    @ObservedObject private var localizationSettings = AppSettings.shared  // 语言变了重画对话区

    /// 只画消息列表，输入框在外。
    var body: some View {
        let _ = localizationSettings.localizationRevision  // 界面语言变了重取文案
        chatList  // 只嵌列表，输入框在 ExplanationChatView
    }

    /// 讲解栏用过滤后的消息，进化栏用全量。
    private var displayedChatMessages: [ChatMessage] {
        if viewModel.rightPageTab == .readingAssistant {  // 讲解栏不展示翻译过程消息
            return viewModel.assistant.explanationDisplayMessages  // 已滤掉翻译轮
        }
        return viewModel.assistant.chatMessages  // 进化栏要过程卡，用全量
    }

    /// 气泡列表；流式时钉在 loading 锚点。
    private var chatList: some View {
        ScrollViewReader { proxy in  // 用 proxy 钉 loading 或最后一条
            ScrollView {  // 竖向滚；新消息靠 onChange 吸底
                LazyVStack(alignment: .leading, spacing: 14) {  // 只画可见气泡，避免长对话卡
                    ForEach(displayedChatMessages) { message in  // 按 id 稳定身份，编辑不丢滚动
                        chatBubble(for: message)  // 用户/助手分叉
                            .id(message.id)  // scrollTo 用这条的 id
                    }

                    if showsActiveStreamingBubble {  // 进行中优先钉 loading，不要钉旧消息
                        streamingBubble  // 过程卡或生成中
                            .id("loading")  // 流式吸底锚点，和 scrollTo 对上
                    }
                }
                .padding(.horizontal, 36)  // 和书页左右边距对齐
                .padding(.vertical, 32)  // 顶底留白，避免贴工具条
            }
            .onChange(of: displayedChatMessages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingResponse) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isLoading) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    /// 一条气泡。用户右、助手左。
    private func chatBubble(for message: ChatMessage) -> some View {
        Group {
            if message.role == .assistant {  // 助手左、带过程卡和编辑
                VStack(alignment: .leading, spacing: 10) {  // 过程卡在上，正文在下
                    if !message.content.isEmpty {
                        assistantContent(message)  // 能改就 TextEditor，否则只读
                    }
                }
                .contextMenu {  // 右键：存/读/复制/删
                    assistantMessageMenu(for: message)  // 助手气泡菜单
                }
                .help(BookL10n.string("help.aiMessageContext"))  // 告诉用户可以右键
            } else {
                bubbleContent(message.content, isUser: true)  // 用户气泡，次要墨色
                .contextMenu {  // 右键：存/读/复制/删
                    userMessageMenu(for: message)  // 用户气泡只有复制和删
                }
                .help(BookL10n.string("help.chatMessageContext"))  // 告诉用户可以右键
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)  // 撑满宽，左对齐
    }

    @ViewBuilder
    /// 改/存/读/删。
    private func assistantMessageMenu(for message: ChatMessage) -> some View {
        Button {
            viewModel.assistant.saveAssistantMessage(id: message.id)  // 把这条助手输出存成文件
        } label: {
            Label(BookL10n.string("action.saveAIOutput"), systemImage: "square.and.arrow.down")  // 存盘图标，文案走目录
        }
        .disabled(message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)  // 空白输出不让存、不让读

        Button {
            viewModel.assistant.readAssistantMessage(id: message.id)  // 朗读这条；正在读再点就停
        } label: {
            Label(viewModel.assistant.isSpeakingExplanation ? BookL10n.string("action.readExplanationStop") : BookL10n.string("action.speechThisMessage"), systemImage: viewModel.assistant.isSpeakingExplanation ? "stop.fill" : "speaker.wave.2.fill")  // 正在读就显示停，否则读这条
        }
        .disabled(message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isRunning)  // 空正文或整页在跑就不要抢朗读

        Divider()  // 危险项和复制分开

        Button {
            copyToPasteboard(message.content)  // 只拷纯文本，不带过程卡
        } label: {
            Label(BookL10n.string("action.copyContent"), systemImage: "doc.on.doc")  // 复制正文
        }
        .disabled(message.content.isEmpty)

        Button(role: .destructive) {
            viewModel.assistant.deleteChatMessage(id: message.id)  // 删这条；至少留欢迎
        } label: {
            Label(BookL10n.string("action.deleteAIMessage"), systemImage: "trash")  // 删助手消息
        }
        .disabled(viewModel.isRunning || viewModel.chatMessages.count <= 1)  // 跑着或只剩欢迎不能删
    }

    @ViewBuilder
    /// 复制。
    private func userMessageMenu(for message: ChatMessage) -> some View {
        Button {
            copyToPasteboard(message.content)  // 只拷纯文本，不带过程卡
        } label: {
            Label(BookL10n.string("action.copyContent"), systemImage: "doc.on.doc")  // 复制正文
        }
        .disabled(message.content.isEmpty)  // 空串不进剪贴板

        Divider()  // 危险项和复制分开

        Button(role: .destructive) {  // 删消息，至少留欢迎
            viewModel.assistant.deleteChatMessage(id: message.id)  // 删这条；至少留欢迎
        } label: {
            Label(BookL10n.string("action.deleteMessage"), systemImage: "trash")  // 删用户消息
        }
        .disabled(viewModel.isRunning || viewModel.chatMessages.count <= 1)  // 跑着或只剩欢迎不能删
    }

    /// 只读正文，可带过程卡。
    private func assistantContent(_ message: ChatMessage) -> some View {
        Group {
            if viewModel.assistant.canEditExplanationMessage(message) && !viewModel.isRunning {  // 欢迎和运行中的不让改
                editableAssistantContent(message)  // 就地改，写回会话
            } else {
                bubbleContent(message.content, isUser: false)  // 助手只读，主墨色
            }
        }
    }

    /// 就地编辑。
    private func editableAssistantContent(_ message: ChatMessage) -> some View {
        TextEditor(text: Binding(  // 就地改助手正文，写回会话
            get: { messageContent(for: message.id) },  // 按 id 取当前草稿，避免闭包抓旧 message
            set: { viewModel.assistant.updateAssistantMessage(id: message.id, content: $0) }  // 逐次写回，不另开保存
        ))
        .font(BookTheme.readingContentFont)  // 和左页同一套正文字
        .foregroundStyle(BookTheme.ink)  // 主墨，助手正文
        .lineSpacing(BookTheme.readingLineSpacing)  // 和左页行距一致
        .scrollContentBackground(.hidden)  // 去掉 TextEditor 系统底，融入书页
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)  // 短回复也留编辑高度
        .disabled(viewModel.isRunning)  // 跑着锁编辑，避免和流式打架
    }

    /// 正文排版。
    private func bubbleContent(_ text: String, isUser: Bool) -> some View {
        Text(text)  // 纯文本气泡
            .font(BookTheme.readingContentFont)  // 和左页同一套正文字
            .foregroundStyle(isUser ? BookTheme.inkSecondary : BookTheme.ink)  // 用户略淡，助手用主墨
            .lineSpacing(BookTheme.readingLineSpacing)  // 和左页行距一致
            .frame(maxWidth: .infinity, alignment: .leading)  // 撑满宽，左对齐
            .multilineTextAlignment(.leading)  // 长行左对齐
            .textSelection(.enabled)  // 只读也能划词
    }

    /// 进行中的一条：过程卡或生成中。
    private var streamingBubble: some View {
        llmStreamingContent
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    /// 书内 LLM 流式正文；还没字就显示生成中。
    private var llmStreamingContent: some View {
        if !viewModel.streamingResponse.isEmpty {  // 已有流式正文就画出来
            bubbleContent(viewModel.streamingResponse, isUser: false)  // 未落盘正文，样式同助手
        } else {
            HStack(spacing: 10) {  // 还没任何输出时的等待行
                ProgressView().controlSize(.small)  // 小转圈，不抢正文
                Text(BookL10n.string("llm.generating"))  // 书内 LLM 还没第一个 token
                    .font(BookTheme.captionFont)  // 状态用说明字号
                    .foregroundStyle(BookTheme.inkSecondary)  // 次要墨，别压正文
            }
        }
    }

    /// 按 id 取当前正文，编辑中用草稿。
    private func messageContent(for id: UUID) -> String {
        viewModel.chatMessages.first(where: { $0.id == id })?.content ?? ""  // 找不到当空串，避免 TextEditor 崩
    }

    /// 复制纯文本。
    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()  // 清掉旧类型，只留纯文本
        NSPasteboard.general.setString(text, forType: .string)  // 系统剪贴板，给其它 App 粘
    }

    /// 讲解只在 explanation 任务时出流式泡；进化看 isLoading。
    private var showsActiveStreamingBubble: Bool {
        return viewModel.isLoading
            && viewModel.assistant.readingAssistantActiveTask == .explanation
            && !viewModel.assistant.showsExplanationProgressSheet  // 全文讲解流在弹出层
    }

    /// 新消息钉在底。
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if showsActiveStreamingBubble {  // 进行中优先钉 loading，不要钉旧消息
            withAnimation(.easeOut(duration: 0.2)) {  // 短动画，避免跳动
                proxy.scrollTo("loading", anchor: .bottom)  // 钉流式泡底
            }
            return  // 已经钉过 loading
        }

        if let last = displayedChatMessages.last {  // 没有流式就钉最后一条已落盘
            withAnimation(.easeOut(duration: 0.2)) {  // 短动画，避免跳动
                proxy.scrollTo(last.id, anchor: .bottom)  // 钉最后一条底
            }
        }
    }
}

import AppKit
import SwiftUI

/// 右页讲解 / 进化对话区：消息列表与流式输出，不含输入框。
struct ExplanationChatTranscriptView: View {
    @EnvironmentObject private var viewModel: ReadingViewModel

    var body: some View {
        chatList
    }

    private var displayedChatMessages: [ChatMessage] {
        if viewModel.rightPageTab == .readingAssistant {
            return viewModel.assistant.explanationDisplayMessages
        }
        return viewModel.assistant.chatMessages
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(displayedChatMessages) { message in
                        chatBubble(for: message)
                            .id(message.id)
                    }

                    if showsActiveStreamingBubble {
                        streamingBubble
                            .id("loading")
                    }
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 32)
            }
            .onChange(of: displayedChatMessages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.evolution.showsExecutionTrace) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingThinking) { _ in
                guard viewModel.evolution.showsExecutionTrace else { return }
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingResponse) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingToolSteps.count) { _ in
                guard viewModel.evolution.showsExecutionTrace else { return }
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isLoading) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func chatBubble(for message: ChatMessage) -> some View {
        Group {
            if message.role == .assistant {
                VStack(alignment: .leading, spacing: 10) {
                    if message.hasExecutionTrace, viewModel.rightPageTab == .aiEvolution {
                        AssistantExecutionTraceCard(
                            thinking: message.thinking,
                            toolSteps: message.toolSteps,
                            defaultExpanded: viewModel.rightPageTab == .aiEvolution
                        )
                    }
                    if !message.content.isEmpty {
                        assistantContent(message)
                    }
                }
                .contextMenu {
                    assistantMessageMenu(for: message)
                }
                .help(BookL10n.string("help.aiMessageContext"))
            } else {
                bubbleContent(message.content, isUser: true)
                .contextMenu {
                    userMessageMenu(for: message)
                }
                .help(BookL10n.string("help.chatMessageContext"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func assistantMessageMenu(for message: ChatMessage) -> some View {
        Button {
            viewModel.assistant.saveAssistantMessage(id: message.id)
        } label: {
            Label(BookL10n.string("action.saveAIOutput"), systemImage: "square.and.arrow.down")
        }
        .disabled(message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        Button {
            viewModel.assistant.readAssistantMessage(id: message.id)
        } label: {
            Label(viewModel.assistant.isSpeakingExplanation ? BookL10n.string("action.readExplanationStop") : BookL10n.string("action.speechThisMessage"), systemImage: viewModel.assistant.isSpeakingExplanation ? "stop.fill" : "speaker.wave.2.fill")
        }
        .disabled(message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isRunning)

        Divider()

        Button {
            copyToPasteboard(message.content)
        } label: {
            Label(BookL10n.string("action.copyContent"), systemImage: "doc.on.doc")
        }
        .disabled(message.content.isEmpty)

        if message.hasExecutionTrace, viewModel.rightPageTab == .aiEvolution {
            Button {
                copyToPasteboard(message.executionTraceText)
            } label: {
                Label(BookL10n.string("action.copyTrace"), systemImage: "timeline.selection")
            }
        }

        Button(role: .destructive) {
            viewModel.assistant.deleteChatMessage(id: message.id)
        } label: {
            Label(BookL10n.string("action.deleteAIMessage"), systemImage: "trash")
        }
        .disabled(viewModel.isRunning || viewModel.chatMessages.count <= 1)
    }

    @ViewBuilder
    private func userMessageMenu(for message: ChatMessage) -> some View {
        Button {
            copyToPasteboard(message.content)
        } label: {
            Label(BookL10n.string("action.copyContent"), systemImage: "doc.on.doc")
        }
        .disabled(message.content.isEmpty)

        Divider()

        Button(role: .destructive) {
            viewModel.assistant.deleteChatMessage(id: message.id)
        } label: {
            Label(BookL10n.string("action.deleteMessage"), systemImage: "trash")
        }
        .disabled(viewModel.isRunning || viewModel.chatMessages.count <= 1)
    }

    private func assistantContent(_ message: ChatMessage) -> some View {
        Group {
            if viewModel.assistant.canEditExplanationMessage(message) && !viewModel.isRunning {
                editableAssistantContent(message)
            } else {
                bubbleContent(message.content, isUser: false)
            }
        }
    }

    private func editableAssistantContent(_ message: ChatMessage) -> some View {
        TextEditor(text: Binding(
            get: { messageContent(for: message.id) },
            set: { viewModel.assistant.updateAssistantMessage(id: message.id, content: $0) }
        ))
        .font(BookTheme.readingContentFont)
        .foregroundStyle(BookTheme.ink)
        .lineSpacing(BookTheme.readingLineSpacing)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .disabled(viewModel.isRunning)
    }

    private func bubbleContent(_ text: String, isUser: Bool) -> some View {
        Text(text)
            .font(BookTheme.readingContentFont)
            .foregroundStyle(isUser ? BookTheme.inkSecondary : BookTheme.ink)
            .lineSpacing(BookTheme.readingLineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .textSelection(.enabled)
    }

    private var streamingBubble: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.evolution.showsExecutionTrace {
                cursorStreamingContent
            } else {
                llmStreamingContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var cursorStreamingContent: some View {
        if !viewModel.streamingThinking.isEmpty || !viewModel.streamingToolSteps.isEmpty {
            AssistantExecutionTraceCard(
                thinking: viewModel.streamingThinking.isEmpty ? nil : viewModel.streamingThinking,
                toolSteps: viewModel.streamingToolSteps.isEmpty ? nil : viewModel.streamingToolSteps,
                isLive: true,
                defaultExpanded: true
            )
        } else if !viewModel.streamingToolStatus.isEmpty {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(viewModel.streamingToolStatus)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkSecondary)
            }
        }
        if !viewModel.streamingResponse.isEmpty {
            bubbleContent(viewModel.streamingResponse, isUser: false)
        } else if viewModel.streamingThinking.isEmpty
                    && viewModel.streamingToolSteps.isEmpty
                    && viewModel.streamingToolStatus.isEmpty {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(viewModel.rightPageTab == .aiEvolution ? BookL10n.string("vm.evolutionRunning") : BookL10n.string("evolution.cursorExecuting"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkSecondary)
            }
        }
    }

    @ViewBuilder
    private var llmStreamingContent: some View {
        if !viewModel.streamingResponse.isEmpty {
            bubbleContent(viewModel.streamingResponse, isUser: false)
        } else {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(BookL10n.string("llm.generating"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkSecondary)
            }
        }
    }

    private func messageContent(for id: UUID) -> String {
        viewModel.chatMessages.first(where: { $0.id == id })?.content ?? ""
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private var showsActiveStreamingBubble: Bool {
        if viewModel.rightPageTab == .aiEvolution {
            return viewModel.isLoading
        }
        return viewModel.isLoading && viewModel.assistant.readingAssistantActiveTask == .explanation
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if showsActiveStreamingBubble {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("loading", anchor: .bottom)
            }
            return
        }

        if let last = displayedChatMessages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

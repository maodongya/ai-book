import AppKit
import SwiftUI

struct ExplanationChatView: View {
    @EnvironmentObject private var viewModel: ReadingViewModel
    @ObservedObject private var settings = AppSettings.shared
    @State private var editingMessageIDs: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.rightPageTab {
            case .readingAssistant:
                readingAssistantPage
            case .aiEvolution:
                aiEvolutionPage
            }
        }
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            settings.refreshCursorAPIKeyFromSources()
        }
    }

    private var readingAssistantPage: some View {
        VStack(spacing: 0) {
            configurationNotice

            readingAssistantPanelSwitcher

            Group {
                switch viewModel.readingAssistantPanel {
                case .explanation:
                    explanationPanel
                case .translation:
                    translationPanel
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            composer(for: .readingAssistant)
        }
    }

    private var readingAssistantPanelSwitcher: some View {
        Picker("右页分栏", selection: $viewModel.readingAssistantPanel) {
            ForEach(ReadingAssistantPanel.allCases) { panel in
                Text(panel.rawValue).tag(panel)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var explanationPanel: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.chatMessages.count <= 1 && !viewModel.isLoading {
                explanationPlaceholder
            }

            chatList
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            SelectableTextView(
                text: $viewModel.explanationSelectionText,
                onSelectionChange: { selection, _ in
                    viewModel.updateExplanationPanelSelection(selection)
                },
                appearance: .editor,
                isEditable: false,
                selectAllSignal: viewModel.explanationSelectAllSignal
            )
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)

            VStack {
                HStack(spacing: 8) {
                    Spacer()
                    explanationToolbar
                }
                Spacer()
            }
            .padding(10)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    private var explanationToolbar: some View {
        HStack(spacing: 8) {
            explanationToolbarButton(title: "新建", icon: "doc.badge.plus") {
                viewModel.newExplanationDocument()
            }
            .disabled(viewModel.isRunning)

            explanationToolbarButton(title: "保存", icon: "square.and.arrow.down") {
                viewModel.saveExplanationDocument()
            }
            .disabled(!viewModel.hasExplanationContent)

            explanationToolbarButton(title: "打开", icon: "folder") {
                viewModel.openExplanationDocument()
            }
            .disabled(viewModel.isRunning)

            explanationToolbarButton(title: "全选", icon: "selection.pin.in.out") {
                viewModel.selectAllExplanation()
            }
            .disabled(!viewModel.hasExplanationContent || viewModel.isRunning)

            explanationToolbarButton(title: "清空", icon: "trash") {
                viewModel.clearExplanation()
            }
            .disabled(viewModel.isRunning || !viewModel.hasExplanationContent)

            if viewModel.isSpeakingExplanation && !viewModel.isRunning {
                explanationToolbarButton(
                    title: viewModel.isExplanationSpeechPaused ? "继续" : "暂停",
                    icon: viewModel.isExplanationSpeechPaused ? "play.fill" : "pause.fill"
                ) {
                    viewModel.toggleExplanationSpeechPause()
                }
            }

            explanationToolbarButton(
                title: viewModel.isSpeakingExplanation ? "停止" : "朗读",
                icon: viewModel.isSpeakingExplanation ? "stop.fill" : "speaker.wave.2.fill"
            ) {
                viewModel.readExplanationAloud()
            }
            .disabled(viewModel.isRunning || (!viewModel.hasExplanationContent && !viewModel.isSpeakingExplanation))
        }
    }

    private func explanationToolbarButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background { lessonPlanToolbarCapsule }
        }
        .buttonStyle(.plain)
    }

    private var translationPanel: some View {
        lessonPlanEditor
    }

    private var explanationPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("选中左页文字后点击「选择讲解」", systemImage: "sparkles.text.clipboard")
                .font(BookTheme.labelFont)
                .foregroundStyle(BookTheme.ink.opacity(0.72))
            Text("也可在顶栏「讲解操作」或「读书操作」中使用「全文讲解」；支持新建、保存、打开、全选、清空与朗读。")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
                .lineSpacing(4)
        }
        .padding(24)
        .allowsHitTesting(false)
    }

    private var aiEvolutionPage: some View {
        VStack(spacing: 0) {
            configurationNotice

            EvolutionUtilityTabsPanel(
                commands: viewModel.evolutionCommands,
                projectPath: SelfEvolution.sourceProjectPath(),
                isRunning: viewModel.isRunning,
                executingCommandNumber: viewModel.executingEvolutionCommandNumber,
                budget: viewModel.evolutionTokenBudget,
                showsAgentTrace: viewModel.showsEvolutionExecutionTrace,
                liveToolLabel: viewModel.evolutionLiveToolLabel,
                canRunEvolution: viewModel.canRunEvolution,
                isEvolutionRebuilding: viewModel.isEvolutionRebuilding,
                clearChatDisabled: viewModel.chatMessages.count <= 1,
                onEvolve: { viewModel.startEvolution() },
                onStop: { viewModel.stopCurrentRun() },
                onClear: { viewModel.clearChat() }
            )

            if viewModel.isEvolutionRebuilding {
                EvolutionRebuildBanner(status: viewModel.evolutionRebuildStatus)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
            }

            chatList
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            composer(for: .aiEvolution)
        }
    }

    @ViewBuilder
    private var configurationNotice: some View {
        if viewModel.rightPageTab == .aiEvolution {
            if settings.explanationSource == .cursor && !settings.isCursorRunnable {
                if settings.isLLMConfigured {
                    llmFallbackBanner
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                } else {
                    CursorConfigPanel()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
            } else if settings.explanationSource == .llm && !settings.isLLMConfigured {
                LLMConfigPanel()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
        } else if settings.explanationSource == .cursor && !settings.isCursorRunnable {
            if settings.isLLMConfigured {
                llmFallbackBanner
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            } else {
                CursorConfigPanel()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }
        } else if settings.explanationSource == .llm && !settings.isLLMConfigured {
            LLMConfigPanel()
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func composer(for mode: RightPageTab) -> some View {
        let useCursor = settings.isCursorRunnable && settings.explanationSource == .cursor
        if useCursor {
            CursorComposerView(mode: mode)
        } else {
            LLMComposerView(mode: mode)
        }
    }

    private var llmFallbackBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(BookTheme.gold)
            Text("\(cursorFallbackReason)，对话与进化将自动使用「\(settings.provider.rawValue)」大模型。")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BookTheme.selection.opacity(0.3))
        }
    }

    private var cursorFallbackReason: String {
        if !settings.isCursorBridgeReady {
            return settings.cursorBridgeStatusMessage
        }
        return "未配置 Cursor API Key"
    }

    private var lessonPlanEditor: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lessonPlanPlaceholder
            }

            SelectableTextView(
                text: $viewModel.lessonPlanContent,
                onSelectionChange: { selection, _ in
                    viewModel.updateLessonPlanSelection(selection)
                },
                appearance: .editor,
                isEditable: !viewModel.isRunning,
                selectAllSignal: viewModel.rightSelectAllSignal
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                HStack(spacing: 8) {
                    Spacer()
                    lessonPlanSelectAllButton
                    lessonPlanReadAloudButton
                }
                Spacer()
            }
            .padding(10)

            if viewModel.isLoading && viewModel.readingAssistantActiveTask == .translation {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在生成翻译…")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.leather)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(Color.white.opacity(0.88))
                        .overlay {
                            Capsule()
                                .strokeBorder(BookTheme.pageEdge.opacity(0.75), lineWidth: 1)
                        }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .allowsHitTesting(false)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.70))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(BookTheme.pageEdge.opacity(0.75), lineWidth: 1)
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var lessonPlanSelectAllButton: some View {
        let isEmpty = viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Button {
            viewModel.selectAllRightPage()
        } label: {
            Label("全选", systemImage: "selection.pin.in.out")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(Color.white.opacity(0.88))
                        .overlay {
                            Capsule()
                                .strokeBorder(BookTheme.pageEdge.opacity(0.75), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
        .disabled(isEmpty || viewModel.isRunning)
        .help("全选翻译内容")
    }

    private var lessonPlanReadAloudButton: some View {
        let isEmpty = viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(spacing: 8) {
            if viewModel.isSpeakingExplanation && !viewModel.isRunning {
                Button {
                    viewModel.toggleExplanationSpeechPause()
                } label: {
                    Label(
                        viewModel.isExplanationSpeechPaused ? "继续" : "暂停",
                        systemImage: viewModel.isExplanationSpeechPaused ? "play.fill" : "pause.fill"
                    )
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background { lessonPlanToolbarCapsule }
                }
                .buttonStyle(.plain)
                .help(viewModel.isExplanationSpeechPaused ? "继续朗读" : "暂停朗读")
            }

            Button {
                viewModel.readLessonPlanAloud()
            } label: {
                Label(
                    viewModel.isSpeakingExplanation ? "停止" : "朗读",
                    systemImage: viewModel.isSpeakingExplanation ? "stop.fill" : "speaker.wave.2.fill"
                )
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background { lessonPlanToolbarCapsule }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isRunning || (isEmpty && !viewModel.isSpeakingExplanation))
            .help(viewModel.isSpeakingExplanation ? "停止朗读" : "朗读翻译内容（⌘⌥T）")
        }
    }

    private var lessonPlanToolbarCapsule: some View {
        Capsule()
            .fill(Color.white.opacity(0.88))
            .overlay {
                Capsule()
                    .strokeBorder(BookTheme.pageEdge.opacity(0.75), lineWidth: 1)
            }
    }

    private var lessonPlanPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("点击「逐字翻译」开始", systemImage: "sparkles")
                .font(BookTheme.labelFont)
                .foregroundStyle(BookTheme.ink.opacity(0.72))
            Text("在顶栏「翻译操作」选择逐字/整段翻译；生成后可编辑，并点击右上角朗读或 ⌘⌥T。")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
                .lineSpacing(4)
        }
        .padding(24)
        .allowsHitTesting(false)
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(viewModel.chatMessages) { message in
                        chatBubble(for: message)
                            .id(message.id)
                    }

                    if showsActiveStreamingBubble {
                        streamingBubble
                            .id("loading")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .padding(.horizontal, 10)
            }
            .onChange(of: viewModel.chatMessages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.showsExecutionTrace) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingThinking) { _ in
                guard viewModel.showsExecutionTrace else { return }
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingResponse) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingToolSteps.count) { _ in
                guard viewModel.showsExecutionTrace else { return }
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isLoading) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func chatBubble(for message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .assistant {
                VStack(alignment: .leading, spacing: 6) {
                    assistantMessageHeader(message)
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
                .help("右键可编辑、保存、朗读、复制或删除此条 AI 输出")
                Spacer(minLength: 36)
            } else {
                Spacer(minLength: 36)
                VStack(alignment: .trailing, spacing: 6) {
                    Label("你", systemImage: "person.fill")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                    bubbleContent(message.content, isUser: true)
                }
                .contextMenu {
                    userMessageMenu(for: message)
                }
                .help("右键可复制或删除此条消息")
            }
        }
    }

    private func assistantMessageHeader(_ message: ChatMessage) -> some View {
        HStack(spacing: 8) {
            Label(assistantLabel, systemImage: "sparkles")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)

            Spacer(minLength: 12)
        }
    }

    @ViewBuilder
    private func assistantMessageMenu(for message: ChatMessage) -> some View {
        Button {
            toggleEditing(message.id)
        } label: {
            Label(isEditing(message.id) ? "完成编辑" : "编辑此条", systemImage: isEditing(message.id) ? "checkmark" : "pencil")
        }

        Button {
            viewModel.saveAssistantMessage(id: message.id)
        } label: {
            Label("保存 AI 输出", systemImage: "square.and.arrow.down")
        }
        .disabled(message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        Button {
            viewModel.readAssistantMessage(id: message.id)
        } label: {
            Label(viewModel.isSpeakingExplanation ? "停止朗读" : "朗读此条", systemImage: viewModel.isSpeakingExplanation ? "stop.fill" : "speaker.wave.2.fill")
        }
        .disabled(message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isRunning)

        Divider()

        Button {
            copyToPasteboard(message.content)
        } label: {
            Label("复制内容", systemImage: "doc.on.doc")
        }
        .disabled(message.content.isEmpty)

        if message.hasExecutionTrace, viewModel.rightPageTab == .aiEvolution {
            Button {
                copyToPasteboard(message.executionTraceText)
            } label: {
                Label("复制执行过程", systemImage: "timeline.selection")
            }
        }

        Button(role: .destructive) {
            editingMessageIDs.remove(message.id)
            viewModel.deleteChatMessage(id: message.id)
        } label: {
            Label("删除此条 AI 输出", systemImage: "trash")
        }
        .disabled(viewModel.isRunning || viewModel.chatMessages.count <= 1)
    }

    @ViewBuilder
    private func userMessageMenu(for message: ChatMessage) -> some View {
        Button {
            copyToPasteboard(message.content)
        } label: {
            Label("复制内容", systemImage: "doc.on.doc")
        }
        .disabled(message.content.isEmpty)

        Divider()

        Button(role: .destructive) {
            viewModel.deleteChatMessage(id: message.id)
        } label: {
            Label("删除此条消息", systemImage: "trash")
        }
        .disabled(viewModel.isRunning || viewModel.chatMessages.count <= 1)
    }

    private func assistantContent(_ message: ChatMessage) -> some View {
        Group {
            if isEditing(message.id) {
                editableAssistantContent(message)
            } else {
                bubbleContent(message.content, isUser: false)
            }
        }
    }

    private func editableAssistantContent(_ message: ChatMessage) -> some View {
        TextEditor(text: Binding(
            get: { messageContent(for: message.id) },
            set: { viewModel.updateAssistantMessage(id: message.id, content: $0) }
        ))
        .font(BookTheme.bodyFont)
        .foregroundStyle(BookTheme.ink)
        .lineSpacing(6)
        .scrollContentBackground(.hidden)
        .frame(minHeight: 120)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.78))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(BookTheme.gold.opacity(0.45), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        }
    }

    private func bubbleContent(_ text: String, isUser: Bool) -> some View {
        Text(text)
            .font(BookTheme.bodyFont)
            .foregroundStyle(isUser ? BookTheme.leatherShadow : BookTheme.ink)
            .lineSpacing(6)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isUser ? BookTheme.gold.opacity(0.86) : Color.white.opacity(0.66))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isUser ? BookTheme.goldSoft.opacity(0.62) : BookTheme.pageEdge.opacity(0.72),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(isUser ? 0.08 : 0.05), radius: 8, y: 3)
            }
            .textSelection(.enabled)
    }

    private var streamingBubble: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Label(assistantLabel, systemImage: "sparkles")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)

                if viewModel.showsExecutionTrace {
                    cursorStreamingContent
                } else {
                    llmStreamingContent
                }
            }
            Spacer(minLength: 36)
        }
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
                Text(viewModel.rightPageTab == .aiEvolution ? "AI 进化执行中…" : "Cursor 正在执行…")
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
                Text("大模型生成中…")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkSecondary)
            }
        }
    }

    private var assistantLabel: String {
        if viewModel.rightPageTab == .aiEvolution {
            return "AI进化"
        }
        return settings.explanationSource == .cursor ? "Cursor" : "读书助手"
    }

    private func isEditing(_ id: UUID) -> Bool {
        editingMessageIDs.contains(id)
    }

    private func toggleEditing(_ id: UUID) {
        if editingMessageIDs.contains(id) {
            editingMessageIDs.remove(id)
        } else {
            editingMessageIDs.insert(id)
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
        return viewModel.isLoading && viewModel.readingAssistantActiveTask == .explanation
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if showsActiveStreamingBubble {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("loading", anchor: .bottom)
            }
            return
        }

        if let last = viewModel.chatMessages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

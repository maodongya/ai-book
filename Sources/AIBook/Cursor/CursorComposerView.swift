import SwiftUI

struct CursorComposerView: View {
    var mode: RightPageTab = .readingAssistant

    @EnvironmentObject private var viewModel: ReadingViewModel
    @ObservedObject private var settings = AppSettings.shared
    @State private var showingAdvancedControls = false

    private var canSend: Bool {
        let hasText = !activeChatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if mode == .aiEvolution {
            return hasText && !viewModel.isRunning && viewModel.canRunEvolution
        }
        return hasText && !viewModel.isRunning
    }

    private var activeChatInput: String {
        mode == .readingAssistant ? viewModel.readingChatInput : viewModel.evolutionChatInput
    }

    private var activeChatInputBinding: Binding<String> {
        Binding(
            get: { mode == .readingAssistant ? viewModel.readingChatInput : viewModel.evolutionChatInput },
            set: { newValue in
                if mode == .readingAssistant {
                    viewModel.readingChatInput = newValue
                } else {
                    viewModel.evolutionChatInput = newValue
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            compactControls
            inputBox
            actionRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.58))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(BookTheme.pageEdge.opacity(0.9), lineWidth: 1)
                }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .background {
            Button("") {
                if canSend { sendActiveChatInput() }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
        }
    }

    private var compactControls: some View {
        Group {
            if mode == .aiEvolution {
                evolutionComposerSummary
            } else {
                DisclosureGroup(isExpanded: $showingAdvancedControls) {
                    VStack(alignment: .leading, spacing: 8) {
                        modelControlsRow
                        contextUsageControls
                    }
                    .padding(.top, 8)
                } label: {
                    HStack(spacing: 8) {
                        Label(cursorSummary, systemImage: "cpu")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.leather)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        compactUsageMeter
                    }
                }
                .font(BookTheme.captionFont)
                .tint(BookTheme.leather)
            }
        }
    }

    private var evolutionComposerSummary: some View {
        HStack(spacing: 8) {
            Label("模型见上方「进化」Tab", systemImage: "slider.horizontal.3")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
                .lineLimit(1)
            Spacer(minLength: 8)
            compactUsageMeter
        }
        .font(BookTheme.captionFont)
    }

    private var modelControlsRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BookTheme.leather)
                Text("模型")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Picker("模型", selection: Binding(
                    get: { settings.selectedCursorModel },
                    set: { settings.selectedCursorModel = $0 }
                )) {
                    ForEach(CursorModelOption.allCases) { model in
                        Text(model.label).tag(model)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 170)
            }

            Spacer()

            if settings.isCursorRunnable {
                Label("Cursor 已就绪", systemImage: "checkmark.circle.fill")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(.green)
            } else if settings.isCursorBridgeReady {
                Label("需 API Key", systemImage: "key.fill")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(.orange)
            } else {
                Label("桥接未就绪", systemImage: "exclamationmark.circle")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var contextUsage: CursorContextUsage {
        mode == .readingAssistant ? viewModel.cursorContextUsage : viewModel.evolutionContextUsage
    }

    private var contextUsageControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("原文节选占比")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Spacer()
                Text("\(Int(settings.cursorContextPercent))%")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)
                if contextUsage.fileTotalCharacters > 0 {
                    Text("· \(contextUsage.fileCharacters)/\(contextUsage.fileTotalCharacters) 字")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                }
            }

            Slider(value: $settings.cursorContextPercent, in: 10 ... 100, step: 5)
                .tint(BookTheme.gold)

            if contextUsage.usesSelectionAnchor {
                Label("节选围绕左页选中内容", systemImage: "scope")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather.opacity(0.85))
            }

            HStack {
                Text("总上下文占用")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Spacer()
                Text("\(contextUsage.formattedUsed)/\(contextUsage.formattedLimit)")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkSecondary)
                Text("(\(Int(contextUsage.percentage))%)")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(contextColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(BookTheme.pageEdge.opacity(0.55))
                    Capsule()
                        .fill(contextGradient)
                        .frame(width: geometry.size.width * contextUsage.percentage / 100.0)
                }
            }
            .frame(height: 8)

            HStack(spacing: 16) {
                usageChip(title: "原文", value: contextUsage.fileCharacters)
                usageChip(title: "对话", value: contextUsage.historyCharacters)
                usageChip(title: "选中", value: contextUsage.selectionCharacters)
                usageChip(title: "输入", value: contextUsage.inputCharacters)
            }
        }
    }

    private var compactUsageMeter: some View {
        Group {
            if mode == .aiEvolution {
                evolutionTokenCompactMeter
            } else {
                HStack(spacing: 6) {
                    Text("上下文 \(Int(contextUsage.percentage))%")
                        .foregroundStyle(contextColor)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(BookTheme.pageEdge.opacity(0.5))
                            Capsule()
                                .fill(contextGradient)
                                .frame(width: geometry.size.width * contextUsage.percentage / 100.0)
                        }
                    }
                    .frame(width: 58, height: 5)
                }
                .font(BookTheme.captionFont)
            }
        }
    }

    private var evolutionTokenBudget: ModelTokenBudget {
        viewModel.evolutionTokenBudget
    }

    private var evolutionTokenCompactMeter: some View {
        HStack(spacing: 6) {
            Text("Token \(evolutionTokenBudget.formattedUsed)/\(evolutionTokenBudget.formattedLimit)")
                .foregroundStyle(evolutionTokenMeterColor)
            Text("剩 \(evolutionTokenBudget.formattedRemaining)")
                .foregroundStyle(BookTheme.inkMuted)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(BookTheme.pageEdge.opacity(0.5))
                    Capsule()
                        .fill(evolutionTokenMeterGradient)
                        .frame(width: geometry.size.width * evolutionTokenBudget.progressPercentage / 100.0)
                }
            }
            .frame(width: 58, height: 5)
        }
        .font(BookTheme.captionFont)
    }

    private var evolutionTokenMeterColor: Color {
        if evolutionTokenBudget.isOverLimit { return BookTheme.vermilion }
        if evolutionTokenBudget.isNearLimit { return .orange }
        return BookTheme.inkSecondary
    }

    private var evolutionTokenMeterGradient: LinearGradient {
        let value = evolutionTokenBudget.percentage
        let colors: [Color]
        if evolutionTokenBudget.isOverLimit {
            colors = [BookTheme.vermilion.opacity(0.85), .orange.opacity(0.85)]
        } else if value >= 90 {
            colors = [.orange.opacity(0.85), BookTheme.gold]
        } else {
            colors = [BookTheme.gold, BookTheme.goldSoft]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    private var inputBox: some View {
        ZStack(alignment: .topLeading) {
            if activeChatInput.isEmpty {
                Text(composerPlaceholder)
                    .font(BookTheme.bodyFont)
                    .foregroundStyle(BookTheme.inkMuted.opacity(0.65))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }

            TextEditor(text: activeChatInputBinding)
                .font(BookTheme.bodyFont)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 56, maxHeight: 88)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .disabled(viewModel.isRunning)
        }
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.82))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(BookTheme.pageEdge, lineWidth: 1)
                }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            BookPageActionButton(
                title: "发送",
                icon: "paperplane.fill",
                isProminent: canSend,
                isDisabled: !canSend
            ) {
                sendActiveChatInput()
            }

            if viewModel.isSpeakingExplanation && !viewModel.isRunning {
                BookPageActionButton(
                    title: viewModel.isExplanationSpeechPaused ? "继续" : "暂停",
                    icon: viewModel.isExplanationSpeechPaused ? "play.fill" : "pause.fill",
                    isDisabled: false
                ) {
                    viewModel.toggleExplanationSpeechPause()
                }

                BookPageActionButton(
                    title: "停止",
                    icon: "stop.fill",
                    isDisabled: false
                ) {
                    viewModel.stopExplanationSpeech()
                }
            } else {
                BookPageActionButton(
                    title: "停止",
                    icon: "stop.fill",
                    isDisabled: !viewModel.isRunning && !viewModel.isSpeakingExplanation
                ) {
                    viewModel.stopCurrentRun()
                }
            }

            Spacer()

            Text("⌘↩ 发送")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)

            if viewModel.isRunning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(runningStatusText)
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.leather)
                }
            } else if viewModel.isSpeakingExplanation {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isExplanationSpeechPaused ? "pause.circle.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(BookTheme.leather)
                    Text(viewModel.isExplanationSpeechPaused ? "朗读已暂停" : "正在朗读讲解…")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.leather)
                }
            }
        }
    }

    private var composerPlaceholder: String {
        switch mode {
        case .readingAssistant:
            return "输入翻译要求，例如：整段白话翻译、保留关键词、减少注释"
        case .aiEvolution:
            return "输入进化相关问题，例如：下一条命令是什么、如何改 Sources/AIBook"
        }
    }

    private func sendActiveChatInput() {
        switch mode {
        case .readingAssistant:
            viewModel.sendChatInput()
        case .aiEvolution:
            viewModel.sendEvolutionChatInput()
        }
    }

    private var runningStatusText: String {
        let text = viewModel.runningStatusText(for: mode)
        return text.isEmpty ? "大模型生成中…" : text
    }

    private var cursorSummary: String {
        "\(settings.selectedCursorModel.label) · \(cursorStatusText)"
    }

    private var cursorStatusText: String {
        if settings.isCursorRunnable { return "已就绪" }
        if settings.isCursorBridgeReady { return "需 API Key" }
        return "桥接未就绪"
    }

    private var contextColor: Color {
        let value = contextUsage.percentage
        if value >= 90 { return .red }
        if value >= 70 { return .orange }
        return BookTheme.inkSecondary
    }

    private var contextGradient: LinearGradient {
        let value = contextUsage.percentage
        let colors: [Color]
        if value >= 90 {
            colors = [.red.opacity(0.85), .orange.opacity(0.85)]
        } else if value >= 70 {
            colors = [.orange.opacity(0.85), BookTheme.gold]
        } else {
            colors = [BookTheme.gold, BookTheme.goldSoft]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    private func usageChip(title: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
            Text("\(value)")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkSecondary)
        }
    }
}

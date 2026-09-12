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

    private var canAnalyze: Bool {
        mode == .aiEvolution
            && !viewModel.isRunning
            && !viewModel.isEvolutionRebuilding
            && viewModel.canRunEvolution
    }

    private var canEvolve: Bool {
        mode == .aiEvolution
            && !viewModel.isRunning
            && !viewModel.isEvolutionRebuilding
            && viewModel.canRunEvolution
            && viewModel.hasPendingOptimization
            && settings.isCursorRunnable
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
            Label(cursorSummary, systemImage: "cursorarrow.rays")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)
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
                Text(BookL10n.string("label.model"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Picker(BookL10n.string("label.model"), selection: Binding(
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
                Label(BookL10n.string("cursor.ready"), systemImage: "checkmark.circle.fill")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(.green)
            } else if settings.isCursorBridgeReady {
                Label(BookL10n.string("cursor.needKeyShort"), systemImage: "key.fill")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(.orange)
            } else {
                Label(BookL10n.string("cursor.bridgeNotReady"), systemImage: "exclamationmark.circle")
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
                Text(BookL10n.string("context.label.excerpt"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Spacer()
                Text("\(Int(settings.cursorContextPercent))%")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)
                if contextUsage.fileTotalCharacters > 0 {
                    Text(BookL10n.format("context.usage.chars", contextUsage.fileCharacters, contextUsage.fileTotalCharacters))
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                }
            }

            Slider(value: $settings.cursorContextPercent, in: 10 ... 100, step: 5)
                .tint(BookTheme.gold)

            if contextUsage.usesSelectionAnchor {
                Label(BookL10n.string("composer.scopeSelection"), systemImage: "scope")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather.opacity(0.85))
            }

            HStack {
                Text(BookL10n.string("context.label.total"))
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
                usageChip(title: BookL10n.string("context.label.source"), value: contextUsage.fileCharacters)
                usageChip(title: BookL10n.string("context.label.chat"), value: contextUsage.historyCharacters)
                usageChip(title: BookL10n.string("context.label.selection"), value: contextUsage.selectionCharacters)
                usageChip(title: BookL10n.string("context.label.input"), value: contextUsage.inputCharacters)
            }
        }
    }

    private var compactUsageMeter: some View {
        Group {
            if mode == .aiEvolution {
                evolutionTokenCompactMeter
            } else {
                HStack(spacing: 6) {
                    Text(BookL10n.format("context.usage.percent", Int(contextUsage.percentage)))
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
            Text(BookL10n.format("token.remaining", evolutionTokenBudget.formattedRemaining))
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
            if mode == .aiEvolution {
                BookPageActionButton(
                    title: BookL10n.string("action.analyze"),
                    icon: "magnifyingglass",
                    isProminent: canAnalyze,
                    isDisabled: !canAnalyze
                ) {
                    viewModel.analyzeOptimizations()
                }

                BookPageActionButton(
                    title: BookL10n.string("action.evolve"),
                    icon: "arrow.triangle.2.circlepath",
                    isProminent: canEvolve,
                    isDisabled: !canEvolve
                ) {
                    viewModel.startEvolution()
                }

                BookPageActionButton(
                    title: BookL10n.string("action.send"),
                    icon: "paperplane.fill",
                    isProminent: canSend,
                    isDisabled: !canSend
                ) {
                    sendActiveChatInput()
                }

                BookPageActionButton(
                    title: BookL10n.string("action.stop"),
                    icon: "stop.fill",
                    isDisabled: !viewModel.isRunning && !viewModel.isSpeakingExplanation
                ) {
                    viewModel.stopCurrentRun()
                }

                Spacer()

                Text(BookL10n.format("composer.evolutionFooter", BookKeyboardShortcuts.evolutionHint))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)

                if viewModel.isRunning {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(runningStatusText)
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.leather)
                    }
                }
            } else {
                BookPageActionButton(
                    title: BookL10n.string("action.send"),
                    icon: "paperplane.fill",
                    isProminent: canSend,
                    isDisabled: !canSend
                ) {
                    sendActiveChatInput()
                }

                if viewModel.isSpeakingExplanation && !viewModel.isRunning {
                    BookPageActionButton(
                        title: viewModel.isExplanationSpeechPaused ? BookL10n.string("action.resume") : BookL10n.string("action.pause"),
                        icon: viewModel.isExplanationSpeechPaused ? "play.fill" : "pause.fill",
                        isDisabled: false
                    ) {
                        viewModel.toggleExplanationSpeechPause()
                    }

                    BookPageActionButton(
                        title: BookL10n.string("action.stop"),
                        icon: "stop.fill",
                        isDisabled: false
                    ) {
                        viewModel.stopExplanationSpeech()
                    }
                } else {
                    BookPageActionButton(
                        title: BookL10n.string("action.stop"),
                        icon: "stop.fill",
                        isDisabled: !viewModel.isRunning && !viewModel.isSpeakingExplanation
                    ) {
                        viewModel.stopCurrentRun()
                    }
                }

                BookPageActionButton(
                    title: BookL10n.string("action.clearReadingContext"),
                    icon: "text.book.closed",
                    isDisabled: viewModel.isRunning || !viewModel.canClearReadingContext
                ) {
                    viewModel.clearReadingContext()
                }

                BookPageActionButton(
                    title: BookL10n.string("action.clearAIContext"),
                    icon: "cpu",
                    isDisabled: viewModel.isRunning || !viewModel.canClearAIContext
                ) {
                    viewModel.clearAIContext()
                }

                Spacer()

                Text(BookL10n.string("composer.sendHint"))
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
                        Text(viewModel.isExplanationSpeechPaused ? BookL10n.string("speech.paused") : BookL10n.string("speech.speakingExplanation"))
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.leather)
                    }
                }
            }
        }
    }

    private var composerPlaceholder: String {
        switch mode {
        case .readingAssistant:
            return BookL10n.string("placeholder.translationShort")
        case .aiEvolution:
            return BookL10n.string("placeholder.evolution")
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
        return text.isEmpty ? BookL10n.string("llm.generating") : text
    }

    private var cursorSummary: String {
        "\(settings.selectedCursorModel.label) · \(cursorStatusText)"
    }

    private var cursorStatusText: String {
        if settings.isCursorRunnable { return BookL10n.string("cursor.ready") }
        if settings.isCursorBridgeReady { return BookL10n.string("cursor.needKeyShort") }
        return BookL10n.string("cursor.bridgeNotReady")
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

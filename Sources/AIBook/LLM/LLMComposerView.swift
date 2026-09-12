import SwiftUI

struct LLMComposerView: View {
    var mode: RightPageTab = .readingAssistant
    var onCollapse: (() -> Void)? = nil

    @EnvironmentObject private var viewModel: ReadingViewModel
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var ollamaCatalog = OllamaModelCatalog.shared
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
                .fill(Color.white.opacity(0.35))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(BookTheme.pageEdge.opacity(0.55), lineWidth: 1)
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
                bookComposerSummary
            }
        }
        .task(id: settings.bookProvider) {
            guard mode == .readingAssistant, settings.bookProvider == .ollama else { return }
            await ollamaCatalog.refresh(baseURL: settings.bookBaseURL, apiKey: settings.bookApiKey)
        }
    }

    private var bookComposerSummary: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 8)

            Button {
                viewModel.openBookSettings()
            } label: {
                Text(BookL10n.string("settings.book"))
                    .font(BookTheme.captionFont)
            }
            .buttonStyle(.plain)
            .foregroundStyle(BookTheme.leather)

            compactUsageMeter

            if let onCollapse {
                Button(action: onCollapse) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BookTheme.leather)
                }
                .buttonStyle(.plain)
                .help(BookL10n.string("composer.hideInput"))
            }
        }
        .font(BookTheme.captionFont)
    }

    private var evolutionComposerSummary: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 8)
            compactUsageMeter
        }
        .font(BookTheme.captionFont)
    }

    private var ollamaModelControls: some View {
        HStack(spacing: 6) {
            if ollamaCatalog.models.isEmpty && !ollamaCatalog.isLoading {
                TextField("model", text: $settings.model)
                    .textFieldStyle(.plain)
                    .font(BookTheme.captionFont)
                    .frame(maxWidth: 120)
            } else {
                Picker(BookL10n.string("label.model"), selection: $settings.model) {
                    ForEach(ollamaCatalog.modelNamesIncluding(settings.model), id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 150)
            }

            Button {
                Task {
                    await ollamaCatalog.refresh(
                        baseURL: settings.baseURL,
                        apiKey: settings.apiKey,
                        force: true
                    )
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(BookTheme.leather)
            .disabled(ollamaCatalog.isLoading)
            .help(BookL10n.string("composer.rescanOllama"))
        }
    }

    private var modelControlsRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BookTheme.leather)
                Text(BookL10n.string("label.provider"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Picker(BookL10n.string("label.provider"), selection: $settings.provider) {
                    if !settings.configuredLLMProviders.isEmpty {
                        Section(BookL10n.string("llm.section.configured")) {
                            ForEach(settings.configuredLLMProviders) { provider in
                                Text(providerLabel(provider)).tag(provider)
                            }
                        }
                        let unconfigured = LLMProvider.allCases.filter { !settings.configuredLLMProviders.contains($0) }
                        if !unconfigured.isEmpty {
                            Section(BookL10n.string("llm.section.unconfigured")) {
                                ForEach(unconfigured) { provider in
                                    Text(provider.rawValue).tag(provider)
                                }
                            }
                        }
                    } else {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 140)
                .onChange(of: settings.provider) { _ in
                    settings.applyProviderDefaults()
                }
            }

            HStack(spacing: 6) {
                Text(BookL10n.string("label.model"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                if settings.provider == .qwen {
                    Picker(BookL10n.string("label.model"), selection: $settings.model) {
                        ForEach(QwenBailianConfig.suggestedModels, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 160)
                } else if settings.provider == .ollama {
                    ollamaModelControls
                } else {
                    TextField("model", text: $settings.model)
                        .textFieldStyle(.plain)
                        .font(BookTheme.captionFont)
                        .frame(maxWidth: 140)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.72))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(BookTheme.pageEdge, lineWidth: 1)
                                }
                        }
                }
            }

            Spacer()

            if settings.isLLMConfigured {
                let count = settings.configuredLLMProviders.count
                Label(
                    count > 1 ? BookL10n.format("llm.connectedMulti", count) : BookL10n.string("llm.connectedSingle"),
                    systemImage: "checkmark.circle.fill"
                )
                .font(BookTheme.captionFont)
                .foregroundStyle(.green)
            } else {
                Label(BookL10n.string("llm.notConfiguredKey"), systemImage: "exclamationmark.circle")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var contextUsage: CursorContextUsage {
        mode == .readingAssistant ? viewModel.llmContextUsage : viewModel.evolutionContextUsage
    }

    private var contextUsageControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(BookL10n.string("context.label.excerpt"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Spacer()
                Text("\(Int(settings.llmContextPercent))%")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)
                if contextUsage.fileTotalCharacters > 0 {
                    Text(BookL10n.format("context.usage.chars", contextUsage.fileCharacters, contextUsage.fileTotalCharacters))
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                }
            }

            Slider(value: $settings.llmContextPercent, in: 10 ... 100, step: 5)
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
        if value >= 100 || evolutionTokenBudget.isOverLimit {
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
                    .font(BookTheme.readingContentFont)
                    .foregroundStyle(BookTheme.inkMuted.opacity(0.65))
                    .lineSpacing(BookTheme.readingLineSpacing)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }

            TextEditor(text: activeChatInputBinding)
                .font(BookTheme.readingContentFont)
                .foregroundStyle(BookTheme.ink)
                .lineSpacing(BookTheme.readingLineSpacing)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 56, maxHeight: 88)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .disabled(viewModel.isRunning)
        }
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.35))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(BookTheme.pageEdge.opacity(0.55), lineWidth: 1)
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
            }

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

    private var runningStatusText: String {
        let text = viewModel.runningStatusText(for: mode)
        return text.isEmpty ? BookL10n.string("llm.generating") : text
    }

    private var composerPlaceholder: String {
        switch mode {
        case .readingAssistant:
            switch viewModel.readingAssistantPanel {
            case .explanation:
                return BookL10n.string("placeholder.explanation")
            case .translation:
                return BookL10n.string("placeholder.translation")
            }
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

    private func providerLabel(_ provider: LLMProvider) -> String {
        let profile = LLMProfileStore.profile(for: provider)
        let model = profile.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if model.isEmpty {
            return provider.rawValue
        }
        return "\(provider.rawValue) · \(model)"
    }

    private var llmSummary: String {
        if settings.isLLMConfigured {
            return settings.llmDisplayLabel
        }
        return BookL10n.format("llm.providerUnconfiguredSuffix", settings.provider.rawValue)
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

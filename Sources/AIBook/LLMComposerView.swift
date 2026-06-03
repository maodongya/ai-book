import SwiftUI

struct LLMComposerView: View {
    var mode: RightPageTab = .readingAssistant

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
        DisclosureGroup(isExpanded: $showingAdvancedControls) {
            VStack(alignment: .leading, spacing: 8) {
                modelControlsRow
                contextUsageControls
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Label(llmSummary, systemImage: "cpu")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)
                    .lineLimit(1)

                Spacer(minLength: 8)

                compactUsageMeter
            }
        }
        .font(BookTheme.captionFont)
        .tint(BookTheme.leather)
        .task(id: settings.provider) {
            guard settings.provider == .ollama else { return }
            await ollamaCatalog.refresh(baseURL: settings.baseURL, apiKey: settings.apiKey)
        }
    }

    private var ollamaModelControls: some View {
        HStack(spacing: 6) {
            if ollamaCatalog.models.isEmpty && !ollamaCatalog.isLoading {
                TextField("model", text: $settings.model)
                    .textFieldStyle(.plain)
                    .font(BookTheme.captionFont)
                    .frame(maxWidth: 120)
            } else {
                Picker("模型", selection: $settings.model) {
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
            .help("重新扫描本机 Ollama 已安装模型")
        }
    }

    private var modelControlsRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BookTheme.leather)
                Text("提供商")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Picker("提供商", selection: $settings.provider) {
                    if !settings.configuredLLMProviders.isEmpty {
                        Section("已配置") {
                            ForEach(settings.configuredLLMProviders) { provider in
                                Text(providerLabel(provider)).tag(provider)
                            }
                        }
                        let unconfigured = LLMProvider.allCases.filter { !settings.configuredLLMProviders.contains($0) }
                        if !unconfigured.isEmpty {
                            Section("未配置") {
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
                Text("模型")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                if settings.provider == .qwen {
                    Picker("模型", selection: $settings.model) {
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
                    count > 1 ? "已连接 · \(count) 家" : "已连接",
                    systemImage: "checkmark.circle.fill"
                )
                .font(BookTheme.captionFont)
                .foregroundStyle(.green)
            } else {
                Label("未配置 Key", systemImage: "exclamationmark.circle")
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
                Text("原文节选占比")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Spacer()
                Text("\(Int(settings.llmContextPercent))%")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)
                if contextUsage.fileTotalCharacters > 0 {
                    Text("· \(contextUsage.fileCharacters)/\(contextUsage.fileTotalCharacters) 字")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                }
            }

            Slider(value: $settings.llmContextPercent, in: 10 ... 100, step: 5)
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

            BookPageActionButton(
                title: "停止",
                icon: "stop.fill",
                isDisabled: !viewModel.isRunning && !viewModel.isSpeakingExplanation
            ) {
                viewModel.stopCurrentRun()
            }

            Spacer()

            Text("⌘↩ 发送")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)

            if viewModel.isRunning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(viewModel.streamingToolStatus.isEmpty ? "大模型生成中…" : viewModel.streamingToolStatus)
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.leather)
                }
            } else if viewModel.isSpeakingExplanation {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isSynthesizingExplanation ? "waveform" : "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(BookTheme.leather)
                    Text(viewModel.isSynthesizingExplanation ? "正在合成讲解语音…" : "正在朗读讲解…")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.leather)
                }
            }
        }
    }

    private var composerPlaceholder: String {
        switch mode {
        case .readingAssistant:
            return "输入翻译要求，例如：翻成白话文、保留古文词义、第二段整段翻译"
        case .aiEvolution:
            return "输入进化相关问题，例如：解释待办命令、Review 改动范围"
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
        return "\(settings.provider.rawValue) · 未配置 Key"
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

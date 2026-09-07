import SwiftUI

/// Settings panel to configure multiple LLM providers at once (command #26).
struct LLMProfilesSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var drafts: [LLMProvider: LLMProfile] = [:]
    @State private var expandedProviders: Set<LLMProvider> = []
    @State private var testingProvider: LLMProvider?
    @State private var testResults: [LLMProvider: (success: Bool, message: String)] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryRow

            HStack(spacing: 10) {
                Text("当前使用")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Picker("当前提供商", selection: $settings.provider) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(providerPickerLabel(provider)).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: settings.provider) { _ in
                    settings.applyProviderDefaults()
                    expandedProviders.insert(settings.provider)
                }
            }

            Text("以下可同时保存多家 API Key；切换「当前使用」不会丢失其他提供商配置。")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)

            ForEach(LLMProvider.allCases) { provider in
                providerCard(provider)
            }
        }
        .onAppear {
            loadDrafts()
            expandedProviders = [settings.provider]
        }
    }

    private var summaryRow: some View {
        let configured = settings.configuredLLMProviders
        return HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(configured.isEmpty ? BookTheme.inkMuted : .green)
            Text("已配置 \(configured.count)/\(LLMProvider.allCases.count) 家")
                .font(BookTheme.labelFont)
                .foregroundStyle(BookTheme.ink)
            if !configured.isEmpty {
                Text(configured.map(\.rawValue).joined(separator: " · "))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                    .lineLimit(2)
            }
        }
    }

    private func providerPickerLabel(_ provider: LLMProvider) -> String {
        let profile = LLMProfileStore.profile(for: provider)
        if LLMConnector.isConfigured(provider: provider, apiKey: profile.apiKey) {
            return "\(provider.rawValue) ✓"
        }
        return provider.rawValue
    }

    private func providerCard(_ provider: LLMProvider) -> some View {
        let isExpanded = expandedProviders.contains(provider)
        let isActive = settings.provider == provider
        let draft = drafts[provider] ?? LLMProfileStore.profile(for: provider)
        let isConfigured = LLMConnector.isConfigured(provider: provider, apiKey: draft.apiKey)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedProviders.remove(provider)
                    } else {
                        expandedProviders.insert(provider)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(BookTheme.inkMuted)
                        .frame(width: 14)

                    Text(provider.rawValue)
                        .font(BookTheme.labelFont)
                        .foregroundStyle(BookTheme.ink)

                    if isActive {
                        Text("当前")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.leatherShadow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background { Capsule().fill(BookTheme.gold) }
                    }

                    Spacer()

                    if isConfigured {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    if let model = draft.model.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                        Text(model)
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.inkMuted)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text(provider.readingHint)
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)

                    if provider == .qwen {
                        qwenBailianFields(provider: provider, draft: draft)
                    } else if provider == .ollama {
                        OllamaSettingsFields(profile: profileBinding(for: provider))
                    } else {
                        profileField("API 地址", text: binding(for: provider, keyPath: \.baseURL))
                        profileField("模型名称", text: binding(for: provider, keyPath: \.model))
                    }

                    if provider.showsAPIKeyField {
                        secureProfileField(
                            provider.apiKeyFieldLabel,
                            text: binding(for: provider, keyPath: \.apiKey)
                        )
                        if provider == .ollama {
                            Text("本地 ollama serve 通常无需 Key；支持 OLLAMA_HOST / OLLAMA_API_KEY 环境变量与 ollama.local.env。保存后点击「刷新模型」可扫描本机已 pull 的模型。")
                                .font(BookTheme.captionFont)
                                .foregroundStyle(BookTheme.inkMuted)
                        }
                    }

                    if provider == .qwen {
                        qwenBailianFooter
                    }

                    HStack(spacing: 10) {
                        Button("保存此提供商") {
                            saveProfile(for: provider)
                        }
                        .buttonStyle(.plain)
                        .font(BookTheme.labelFont)
                        .foregroundStyle(BookTheme.leatherShadow)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background { Capsule().fill(BookTheme.gold) }

                        if settings.provider != provider {
                            Button("设为当前") {
                                settings.provider = provider
                            }
                            .buttonStyle(.plain)
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.leather)
                        }

                        Button {
                            testProfile(for: provider)
                        } label: {
                            Label(
                                testingProvider == provider ? "测试中…" : "测试连接",
                                systemImage: "antenna.radiowaves.left.and.right"
                            )
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.leather)
                        }
                        .buttonStyle(.plain)
                        .disabled(testingProvider == provider || !LLMConnector.isConfigured(provider: provider, apiKey: draft.apiKey))

                        if let result = testResults[provider] {
                            Text(result.message)
                                .font(BookTheme.captionFont)
                                .foregroundStyle(result.success ? .green : BookTheme.leather)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? BookTheme.selection.opacity(0.25) : Color.white.opacity(0.4))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isActive ? BookTheme.gold.opacity(0.5) : BookTheme.pageEdge.opacity(0.6),
                            lineWidth: 1
                        )
                }
        }
    }

    private func qwenBailianFields(provider: LLMProvider, draft: LLMProfile) -> some View {
        let region = QwenBailianRegion.detect(from: draft.baseURL) ?? QwenBailianConfig.defaultRegion

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("百炼地域")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Picker("百炼地域", selection: Binding(
                    get: { region },
                    set: { applyQwenRegion($0, for: provider) }
                )) {
                    ForEach(QwenBailianRegion.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                Text(region.consoleHint)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            }

            profileField("API 地址（Base URL）", text: binding(for: provider, keyPath: \.baseURL))

            VStack(alignment: .leading, spacing: 6) {
                Text("模型名称")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Picker("模型", selection: binding(for: provider, keyPath: \.model)) {
                    ForEach(QwenBailianConfig.suggestedModels, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
                TextField("或手动输入模型 ID", text: binding(for: provider, keyPath: \.model))
                    .textFieldStyle(.plain)
                    .font(BookTheme.bodyFont)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.65))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(BookTheme.pageEdge, lineWidth: 1)
                            }
                    }
            }

            Button("从环境变量 / dashscope.local.env 读取 Key") {
                refreshQwenKeyFromEnvironment(for: provider)
            }
            .buttonStyle(.plain)
            .font(BookTheme.captionFont)
            .foregroundStyle(BookTheme.leather)
        }
    }

    private var qwenBailianFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("接口：POST {Base URL}/chat/completions · Authorization: Bearer {API Key}")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
            Link("打开百炼控制台 API 页", destination: URL(string: QwenBailianConfig.consoleURL)!)
                .font(BookTheme.captionFont)
        }
    }

    private func applyQwenRegion(_ region: QwenBailianRegion, for provider: LLMProvider) {
        var profile = drafts[provider] ?? LLMProfileStore.profile(for: provider)
        profile.baseURL = region.compatibleBaseURL
        drafts[provider] = profile
    }

    private func refreshQwenKeyFromEnvironment(for provider: LLMProvider) {
        var profile = drafts[provider] ?? LLMProfileStore.profile(for: provider)
        profile.apiKey = QwenBailianConfig.resolveAPIKey(stored: "")
        drafts[provider] = profile
    }

    private func profileBinding(for provider: LLMProvider) -> Binding<LLMProfile> {
        Binding(
            get: { drafts[provider] ?? LLMProfileStore.profile(for: provider) },
            set: { drafts[provider] = $0 }
        )
    }

    private func binding(for provider: LLMProvider, keyPath: WritableKeyPath<LLMProfile, String>) -> Binding<String> {
        Binding(
            get: { drafts[provider]?[keyPath: keyPath] ?? LLMProfileStore.profile(for: provider)[keyPath: keyPath] },
            set: { newValue in
                var profile = drafts[provider] ?? LLMProfileStore.profile(for: provider)
                profile[keyPath: keyPath] = newValue
                drafts[provider] = profile
            }
        )
    }

    private func profileField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .font(BookTheme.bodyFont)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.65))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(BookTheme.pageEdge, lineWidth: 1)
                        }
                }
        }
    }

    private func secureProfileField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
            SecureField(title, text: text)
                .textFieldStyle(.plain)
                .font(BookTheme.bodyFont)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.65))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(BookTheme.pageEdge, lineWidth: 1)
                        }
                }
        }
    }

    private func loadDrafts() {
        var loaded: [LLMProvider: LLMProfile] = [:]
        for provider in LLMProvider.allCases {
            loaded[provider] = LLMProfileStore.profile(for: provider)
        }
        drafts = loaded
    }

    private func saveProfile(for provider: LLMProvider) {
        let profile = drafts[provider] ?? LLMProfileStore.profile(for: provider)
        LLMProfileStore.save(profile, for: provider)
        if settings.provider == provider {
            settings.loadLLMProfile(for: provider)
        }
        testResults[provider] = nil
    }

    private func testProfile(for provider: LLMProvider) {
        let draft = drafts[provider] ?? LLMProfileStore.profile(for: provider)
        LLMProfileStore.save(draft, for: provider)
        let configuration = LLMProfileStore.resolvedConfiguration(for: provider)
        testingProvider = provider
        testResults[provider] = nil
        Task {
            do {
                try await LLMService().testConnection(configuration: configuration)
                testResults[provider] = (true, "已连接 \(LLMConnector.displayLabel(provider: provider, model: configuration.model))")
            } catch {
                testResults[provider] = (false, error.localizedDescription)
            }
            testingProvider = nil
        }
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

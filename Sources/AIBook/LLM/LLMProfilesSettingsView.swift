import SwiftUI

/// 多提供商档案编辑。scope=.book 读书，.evolution 进化，两套互不覆盖。
struct LLMProfilesSettingsView: View {
    var scope: LLMProfileScope = .book

    @ObservedObject private var settings = AppSettings.shared
    @State private var drafts: [LLMProvider: LLMProfile] = [:] // 未点保存的草稿，关窗会丢
    @State private var expandedProviders: Set<LLMProvider> = [] // 展开的卡片，默认只开当前启用的
    @State private var testingProvider: LLMProvider? // 正在测连接的那一家，禁重复点
    @State private var testResults: [LLMProvider: (success: Bool, message: String)] = [:] // 测完留在卡片上

    /// 已填 Key 或 Ollama 有地址的，摘要行用。
    private var configuredProviders: [LLMProvider] {
        switch scope {
        case .book: return settings.configuredBookProviders
        case .evolution: return settings.configuredLLMProviders
        }
    }

    /// 当前 scope 正在用的提供商。
    private var activeProvider: LLMProvider {
        switch scope {
        case .book: return settings.bookProvider
        case .evolution: return settings.provider
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryRow

            HStack(spacing: 10) {
                Text(BookL10n.string("label.currentUse"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.settingsPrimary)
                Picker(BookL10n.string("llm.activeProvider"), selection: activeProviderBinding) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(providerPickerLabel(provider)).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .tint(BookTheme.settingsPrimary)
                .onChange(of: settings.bookProvider) { _ in
                    guard scope == .book else { return }
                    applyActiveProviderDefaults()
                    expandedProviders.insert(settings.bookProvider)
                }
                .onChange(of: settings.provider) { _ in
                    guard scope == .evolution else { return }
                    applyActiveProviderDefaults()
                    expandedProviders.insert(settings.provider)
                }
            }

            Text(scope == .book
                ? BookL10n.string("llm.scope.bookHint")
                : BookL10n.string("llm.scope.generalHint"))
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.settingsSecondary)

            ForEach(LLMProvider.allCases) { provider in
                providerCard(provider)
            }
        }
        .onAppear {
            loadDrafts()
            expandedProviders = [activeProvider]
        }
    }

    /// 切换即落盘并加载该家档案。
    private var activeProviderBinding: Binding<LLMProvider> {
        switch scope {
        case .book:
            return $settings.bookProvider
        case .evolution:
            return $settings.provider
        }
    }

    /// 顶上一句：当前启用哪家。
    private var summaryRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(configuredProviders.isEmpty ? BookTheme.settingsSecondary : .green)
            Text(BookL10n.format("llm.providersConfigured", configuredProviders.count, LLMProvider.allCases.count))
                .font(BookTheme.labelFont)
                .foregroundStyle(BookTheme.settingsPrimary)
            if !configuredProviders.isEmpty {
                Text(configuredProviders.map(\.rawValue).joined(separator: " · "))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.settingsSecondary)
                    .lineLimit(2)
            }
        }
    }

    /// Picker 行：已配置标「已填」。
    private func providerPickerLabel(_ provider: LLMProvider) -> String {
        let profile = storedProfile(for: provider)
        if LLMConnector.isConfigured(provider: provider, apiKey: profile.apiKey) {
            return "\(provider.rawValue) ✓"
        }
        return provider.rawValue
    }

    /// 一家提供商的折叠卡：字段 + 保存 + 测连接。
    private func providerCard(_ provider: LLMProvider) -> some View {
        let isExpanded = expandedProviders.contains(provider)
        let isActive = activeProvider == provider
        let draft = drafts[provider] ?? storedProfile(for: provider)
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
                        .foregroundStyle(BookTheme.settingsSecondary)
                        .frame(width: 14)

                    Text(provider.rawValue)
                        .font(BookTheme.labelFont)
                        .foregroundStyle(BookTheme.settingsPrimary)

                    if isActive {
                        Text(BookL10n.string("label.current"))
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.buttonProminentText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background { Capsule().fill(BookTheme.goldGradient) }
                    }

                    Spacer()

                    if isConfigured {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    if let model = draft.model.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                        Text(model)
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.settingsSecondary)
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
                        .foregroundStyle(BookTheme.settingsSecondary)

                    if provider == .qwen {
                        qwenBailianFields(provider: provider, draft: draft)
                    } else if provider == .ollama {
                        OllamaSettingsFields(profile: profileBinding(for: provider))
                    } else {
                        profileField(BookL10n.string("llm.apiAddress"), text: binding(for: provider, keyPath: \.baseURL))
                        profileField(BookL10n.string("qwen.modelName"), text: binding(for: provider, keyPath: \.model))
                    }

                    if provider.showsAPIKeyField {
                        secureProfileField(
                            provider.apiKeyFieldLabel,
                            text: binding(for: provider, keyPath: \.apiKey)
                        )
                        if provider == .ollama {
                            Text(BookL10n.string("ollama.localHint"))
                                .font(BookTheme.captionFont)
                                .foregroundStyle(BookTheme.settingsSecondary)
                        }
                    }

                    if provider == .qwen {
                        qwenBailianFooter
                    }

                    HStack(spacing: 10) {
                        Button(BookL10n.string("action.saveProvider")) {
                            saveProfile(for: provider)
                        }
                        .buttonStyle(.plain)
                        .font(BookTheme.labelFont)
                        .foregroundStyle(BookTheme.buttonProminentText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background { Capsule().fill(BookTheme.goldGradient) }

                        if activeProvider != provider {
                            Button(BookL10n.string("action.setActive")) {
                                setActiveProvider(provider)
                            }
                            .buttonStyle(.plain)
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.settingsPrimary)
                        }

                        Button {
                            testProfile(for: provider)
                        } label: {
                            Label(
                                testingProvider == provider ? BookL10n.string("llm.testing") : BookL10n.string("llm.testConnection"),
                                systemImage: "antenna.radiowaves.left.and.right"
                            )
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.settingsPrimary)
                        }
                        .buttonStyle(.plain)
                        .disabled(testingProvider == provider || !LLMConnector.isConfigured(provider: provider, apiKey: draft.apiKey))

                        if let result = testResults[provider] {
                            Text(result.message)
                                .font(BookTheme.captionFont)
                                .foregroundStyle(result.success ? .green : BookTheme.settingsPrimary)
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

    /// 百炼：地域、模型建议、从环境刷新 Key。
    private func qwenBailianFields(provider: LLMProvider, draft: LLMProfile) -> some View {
        let region = QwenBailianRegion.detect(from: draft.baseURL) ?? QwenBailianConfig.defaultRegion

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(BookL10n.string("qwen.region"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.settingsPrimary)
                Picker(BookL10n.string("qwen.region"), selection: Binding(
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
                    .foregroundStyle(BookTheme.settingsSecondary)
            }

            profileField(BookL10n.string("llm.apiAddressBase"), text: binding(for: provider, keyPath: \.baseURL))

            VStack(alignment: .leading, spacing: 6) {
                Text(BookL10n.string("qwen.modelName"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.settingsPrimary)
                Picker(BookL10n.string("label.model"), selection: binding(for: provider, keyPath: \.model)) {
                    ForEach(QwenBailianConfig.suggestedModels, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
                .tint(BookTheme.settingsPrimary)
                TextField(BookL10n.string("llm.manualModelID"), text: binding(for: provider, keyPath: \.model))
                    .textFieldStyle(.plain)
                    .font(BookTheme.bodyFont)
                    .foregroundStyle(BookTheme.settingsPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(BookTheme.menuItemFill)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(BookTheme.menuItemBorder, lineWidth: 1)
                            }
                    }
            }

            Button(BookL10n.string("qwen.loadKeyFromEnv")) {
                refreshQwenKeyFromEnvironment(for: provider)
            }
            .buttonStyle(.plain)
            .font(BookTheme.captionFont)
            .foregroundStyle(BookTheme.settingsPrimary)
        }
    }

    /// 控制台链接，避免设置页再写死 URL。
    private var qwenBailianFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(BookL10n.string("qwen.apiDoc"))
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.settingsSecondary)
            Link(BookL10n.string("qwen.consoleLink"), destination: URL(string: QwenBailianConfig.consoleURL)!)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.settingsPrimary)
        }
    }

    /// 已落盘档案，不是草稿。
    private func storedProfile(for provider: LLMProvider) -> LLMProfile {
        LLMProfileStore.profile(for: provider, scope: scope)
    }

    /// 切提供商后补默认基址/模型，避免空请求。
    private func applyActiveProviderDefaults() {
        switch scope {
        case .book: settings.applyBookProviderDefaults()
        case .evolution: settings.applyProviderDefaults()
        }
    }

    /// 写入 Store 并展开该卡。
    private func setActiveProvider(_ provider: LLMProvider) {
        switch scope {
        case .book: settings.bookProvider = provider
        case .evolution: settings.provider = provider
        }
    }

    /// 草稿盖成已存值。
    private func loadActiveProfile(for provider: LLMProvider) {
        switch scope {
        case .book: settings.loadBookProfile(for: provider)
        case .evolution: settings.loadLLMProfile(for: provider)
        }
    }

    /// 换地域只改 Base URL，Key 不动。
    private func applyQwenRegion(_ region: QwenBailianRegion, for provider: LLMProvider) {
        var profile = drafts[provider] ?? storedProfile(for: provider)
        profile.baseURL = region.compatibleBaseURL
        drafts[provider] = profile
    }

    /// 从 DASHSCOPE_API_KEY / 本地 env 填进草稿，不自动保存。
    private func refreshQwenKeyFromEnvironment(for provider: LLMProvider) {
        var profile = drafts[provider] ?? storedProfile(for: provider)
        profile.apiKey = QwenBailianConfig.resolveAPIKey(stored: "")
        drafts[provider] = profile
    }

    /// 整份草稿绑定。没有则现读 Store。
    private func profileBinding(for provider: LLMProvider) -> Binding<LLMProfile> {
        Binding(
            get: { drafts[provider] ?? storedProfile(for: provider) },
            set: { drafts[provider] = $0 }
        )
    }

    /// 单个字段绑定，写回 drafts。
    private func binding(for provider: LLMProvider, keyPath: WritableKeyPath<LLMProfile, String>) -> Binding<String> {
        Binding(
            get: { drafts[provider]?[keyPath: keyPath] ?? storedProfile(for: provider)[keyPath: keyPath] },
            set: { newValue in
                var profile = drafts[provider] ?? storedProfile(for: provider)
                profile[keyPath: keyPath] = newValue
                drafts[provider] = profile
            }
        )
    }

    /// 明文输入行。
    private func profileField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.settingsPrimary)
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .font(BookTheme.bodyFont)
                .foregroundStyle(BookTheme.settingsPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(BookTheme.menuItemFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(BookTheme.menuItemBorder, lineWidth: 1)
                        }
                }
        }
    }

    /// Key 用 SecureField。
    private func secureProfileField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.settingsPrimary)
            SecureField(title, text: text)
                .textFieldStyle(.plain)
                .font(BookTheme.bodyFont)
                .foregroundStyle(BookTheme.settingsPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(BookTheme.menuItemFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(BookTheme.menuItemBorder, lineWidth: 1)
                        }
                }
        }
    }

    /// 进页时把各家已存档案拷进 drafts。
    private func loadDrafts() {
        var loaded: [LLMProvider: LLMProfile] = [:]
        for provider in LLMProvider.allCases {
            loaded[provider] = storedProfile(for: provider)
        }
        drafts = loaded
    }

    /// 草稿写入 Store。Ollama 会规范化地址。
    private func saveProfile(for provider: LLMProvider) {
        let profile = drafts[provider] ?? storedProfile(for: provider)
        LLMProfileStore.save(profile, for: provider, scope: scope)
        if activeProvider == provider {
            loadActiveProfile(for: provider)
        }
        testResults[provider] = nil
    }

    /// 用草稿测连接，不先保存。失败文案 enrich 后展示。
    private func testProfile(for provider: LLMProvider) {
        let draft = drafts[provider] ?? storedProfile(for: provider)
        LLMProfileStore.save(draft, for: provider, scope: scope)
        let configuration = LLMProfileStore.resolvedConfiguration(for: provider, scope: scope)
        testingProvider = provider
        testResults[provider] = nil
        Task {
            do {
                try await LLMService().testConnection(configuration: configuration)
                testResults[provider] = (true, BookL10n.format("llm.connectedTest", LLMConnector.displayLabel(provider: provider, model: configuration.model)))
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

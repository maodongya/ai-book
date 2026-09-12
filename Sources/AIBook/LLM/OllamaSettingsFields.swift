import SwiftUI

/// Ollama 设置区：根据本机服务自动发现模型并供选择。
struct OllamaSettingsFields: View {
    @Binding var profile: LLMProfile
    var onRefreshAddress: (() -> Void)?

    @ObservedObject private var catalog = OllamaModelCatalog.shared
    @State private var useCustomModel = false

    private var modelBinding: Binding<String> {
        Binding(
            get: { profile.model },
            set: { profile.model = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            profileField(BookL10n.string("ollama.openAICompat"), text: baseURLBinding)

            HStack(spacing: 8) {
                Text(BookL10n.string("ollama.serviceURL"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.settingsPrimary)
                Text(OllamaConfig.resolvedHost(baseURL: profile.baseURL))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(BookTheme.settingsPrimary)
                    .lineLimit(1)
                Spacer()
                Button(BookL10n.string("action.loadFromEnv")) {
                    applyEnvironmentDefaults()
                }
                .buttonStyle(.plain)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.settingsPrimary)
            }

            modelSection

            if let status = catalog.statusMessage {
                Text(status)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(catalog.models.isEmpty ? BookTheme.settingsPrimary : BookTheme.settingsSecondary)
            }

            Text(OllamaConfig.pullHint)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.settingsSecondary)
        }
        .task(id: profile.baseURL) {
            await refreshModels()
        }
        .onAppear {
            if catalog.models.isEmpty {
                Task { await refreshModels() }
            }
        }
    }

    private var baseURLBinding: Binding<String> {
        Binding(
            get: { profile.baseURL },
            set: { newValue in
                profile.baseURL = OllamaConfig.normalizedOpenAIBaseURL(newValue)
                onRefreshAddress?()
            }
        )
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(BookL10n.string("ollama.localModels"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.settingsPrimary)
                Spacer()
                Button {
                    Task { await refreshModels(force: true) }
                } label: {
                    Label(catalog.isLoading ? BookL10n.string("ollama.scanning") : BookL10n.string("action.refreshModels"), systemImage: "arrow.clockwise")
                        .font(BookTheme.captionFont)
                }
                .buttonStyle(.plain)
                .foregroundStyle(BookTheme.settingsPrimary)
                .disabled(catalog.isLoading)
            }

            if catalog.models.isEmpty && !catalog.isLoading {
                TextField(BookL10n.string("ollama.modelNameField"), text: modelBinding)
                    .textFieldStyle(.plain)
                    .font(BookTheme.bodyFont)
                    .foregroundStyle(BookTheme.settingsPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .ollamaFieldBackground()
            } else {
                Picker(BookL10n.string("ollama.localModels"), selection: modelBinding) {
                    ForEach(catalog.modelNamesIncluding(profile.model), id: \.self) { name in
                        if let info = catalog.models.first(where: { $0.name == name }) {
                            Text(modelPickerTitle(info)).tag(name)
                        } else {
                            Text(name).tag(name)
                        }
                    }
                }
                .pickerStyle(.menu)
                .tint(BookTheme.settingsPrimary)

                if !catalog.models.isEmpty {
                    HStack {
                        Text(BookL10n.string("ollama.manualModel"))
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.settingsPrimary)
                        Spacer()
                        Toggle(BookL10n.string("ollama.manualModel"), isOn: $useCustomModel)
                            .labelsHidden()
                            .tint(BookTheme.gold)
                    }
                }

                if useCustomModel || catalog.models.isEmpty {
                    TextField(BookL10n.string("llm.manualModelID"), text: modelBinding)
                        .textFieldStyle(.plain)
                        .font(BookTheme.bodyFont)
                        .foregroundStyle(BookTheme.settingsPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .ollamaFieldBackground()
                }
            }
        }
    }

    private func modelPickerTitle(_ info: OllamaModelInfo) -> String {
        if let size = info.sizeLabel {
            return "\(info.displayTitle) (\(size))"
        }
        return info.displayTitle
    }

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
                .ollamaFieldBackground()
        }
    }

    private func applyEnvironmentDefaults() {
        if let host = ProcessInfo.processInfo.environment["OLLAMA_HOST"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !host.isEmpty {
            profile.baseURL = OllamaConfig.normalizedOpenAIBaseURL(host)
        }
        let key = OllamaConfig.resolveAPIKey(stored: "")
        if !key.isEmpty {
            profile.apiKey = key
        }
        onRefreshAddress?()
        Task { await refreshModels(force: true) }
    }

    private func refreshModels(force: Bool = false) async {
        await catalog.refresh(
            baseURL: profile.baseURL,
            apiKey: profile.apiKey,
            force: force
        )
        ensureModelSelectionValid()
    }

    private func ensureModelSelectionValid() {
        let names = catalog.modelNamesIncluding(profile.model)
        guard !names.isEmpty else { return }
        if !names.contains(profile.model) {
            profile.model = names[0]
        }
    }
}

private extension View {
    func ollamaFieldBackground() -> some View {
        background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(BookTheme.menuItemFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(BookTheme.menuItemBorder, lineWidth: 1)
                }
        }
    }
}

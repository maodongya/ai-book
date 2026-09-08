import SwiftUI

/// Reading (book) LLM settings — local Ollama first, separate from evolution models.
struct BookSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var ollamaCatalog = OllamaModelCatalog.shared
    @Environment(\.dismiss) private var dismiss
    @State private var bookProfile = LLMProfile.defaults(for: .ollama)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(BookTheme.pageEdge.opacity(0.65))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    providerSection
                    modelSection
                    contextSection
                }
                .padding(20)
            }
        }
        .frame(width: 460)
        .frame(minHeight: 420)
        .background(BookTheme.deskGradient)
        .onAppear {
            syncBookProfileFromSettings()
        }
        .onChange(of: settings.bookProvider) { _ in
            syncBookProfileFromSettings()
        }
        .task(id: settings.bookProvider) {
            guard settings.bookProvider == .ollama else { return }
            await ollamaCatalog.refresh(baseURL: settings.bookBaseURL, apiKey: settings.bookApiKey)
        }
    }

    private var header: some View {
        HStack {
            Label("book 设置", systemImage: "book.closed.fill")
                .font(BookTheme.titleFont)
                .foregroundStyle(BookTheme.leather)
            Spacer()
            Button("完成") { dismiss() }
                .font(BookTheme.bodyFont)
                .foregroundStyle(BookTheme.leather)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var intro: some View {
        Text("读书助手、讲解、翻译与名著补充使用此处配置的大模型，与 AI 进化互不影响。推荐本机 Ollama 本地模型。")
            .font(BookTheme.captionFont)
            .foregroundStyle(BookTheme.inkMuted)
            .lineSpacing(4)
    }

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("提供商")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)

            Picker("提供商", selection: $settings.bookProvider) {
                Text(LLMProvider.ollama.rawValue).tag(LLMProvider.ollama)
                ForEach(LLMProvider.allCases.filter { $0 != .ollama }) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: settings.bookProvider) { _ in
                settings.applyBookProviderDefaults()
            }
        }
    }

    @ViewBuilder
    private var modelSection: some View {
        switch settings.bookProvider {
        case .ollama:
            OllamaSettingsFields(profile: bookProfileBinding) {
                applyBookProfileToSettings()
            }
        case .qwen:
            qwenFields
        default:
            genericCloudFields
        }
    }

    private var qwenFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledField("API Key", text: $settings.bookApiKey, secure: true)
            labeledField("Base URL", text: $settings.bookBaseURL)
            Picker("模型", selection: $settings.bookModel) {
                ForEach(QwenBailianConfig.suggestedModels, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
        }
    }

    private var genericCloudFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            if settings.bookProvider.showsAPIKeyField {
                labeledField(
                    settings.bookProvider == .ollama ? "可选 API Key" : "API Key",
                    text: $settings.bookApiKey,
                    secure: settings.bookProvider != .ollama
                )
            }
            labeledField("Base URL", text: $settings.bookBaseURL)
            labeledField("模型", text: $settings.bookModel)
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("原文节选占比")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Spacer()
                Text("\(Int(settings.bookContextPercent))%")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)
            }
            Slider(value: $settings.bookContextPercent, in: 10 ... 100, step: 5)
                .tint(BookTheme.gold)
            Text("讲解与追问时，附带给模型的左页原文节选比例。")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
        }
    }

    private var bookProfileBinding: Binding<LLMProfile> {
        Binding(
            get: { bookProfile },
            set: { newValue in
                bookProfile = newValue
                applyBookProfileToSettings()
            }
        )
    }

    private func labeledField(_ title: String, text: Binding<String>, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
            Group {
                if secure {
                    SecureField(title, text: text)
                } else {
                    TextField(title, text: text)
                }
            }
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

    private func syncBookProfileFromSettings() {
        bookProfile = LLMProfile(
            apiKey: settings.bookApiKey,
            baseURL: settings.bookBaseURL,
            model: settings.bookModel
        )
    }

    private func applyBookProfileToSettings() {
        settings.bookApiKey = bookProfile.apiKey
        settings.bookBaseURL = bookProfile.baseURL
        settings.bookModel = bookProfile.model
    }
}

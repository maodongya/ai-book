import SwiftUI

struct LLMConfigPanel: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var draftAPIKey = ""
    @State private var showAPIKey = false
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var testSucceeded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .foregroundStyle(BookTheme.gold)
                Text("大模型连接")
                    .font(BookTheme.labelFont)
                    .foregroundStyle(BookTheme.ink)
            }

            let configuredCount = settings.configuredLLMProviders.count
            if settings.isLLMConfigured {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    if configuredCount > 1 {
                        Text("已配置 \(configuredCount) 家 · 当前 \(settings.llmDisplayLabel)")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.inkSecondary)
                            .lineLimit(1)
                    } else {
                        Text("已连接 \(settings.llmDisplayLabel)")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.inkSecondary)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("请在设置中同时配置多家 API Key，或在此选择提供商并保存。")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            }

            Picker("提供商", selection: $settings.provider) {
                ForEach(settings.configuredLLMProviders.isEmpty ? LLMProvider.allCases : settings.configuredLLMProviders + LLMProvider.allCases.filter { !settings.configuredLLMProviders.contains($0) }) { provider in
                    let configured = settings.configuredLLMProviders.contains(provider)
                    Text(configured ? "\(provider.rawValue) ✓" : provider.rawValue).tag(provider)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: settings.provider) { _ in
                settings.applyProviderDefaults()
            }

            Text(settings.provider.readingHint)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)

            if settings.provider.showsAPIKeyField {
                if settings.provider == .ollama {
                    Text("API Key 可选：本地服务通常无需填写；启用 OLLAMA_API_KEY 或远程实例时再填。")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                }

                HStack(spacing: 8) {
                    Group {
                        if showAPIKey {
                            TextField(settings.provider == .ollama ? "可选 API Key" : "sk-...", text: $draftAPIKey)
                        } else {
                            SecureField(settings.provider == .ollama ? "可选 API Key" : "sk-...", text: $draftAPIKey)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(BookTheme.bodyFont)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.72))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(BookTheme.pageEdge, lineWidth: 1)
                            }
                    }

                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .foregroundStyle(BookTheme.inkMuted)
                    }
                    .buttonStyle(.plain)
                }

                Button(settings.provider == .ollama ? "保存配置" : "保存 API Key") {
                    settings.apiKey = draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .buttonStyle(.plain)
                .font(BookTheme.labelFont)
                .foregroundStyle(BookTheme.leatherShadow)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule().fill(BookTheme.gold)
                }
                .disabled(settings.provider.requiresAPIKey && draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack(spacing: 10) {
                Button {
                    testConnection()
                } label: {
                    Label(isTesting ? "测试中…" : "测试连接", systemImage: "antenna.radiowaves.left.and.right")
                        .font(BookTheme.labelFont)
                        .foregroundStyle(BookTheme.leatherShadow)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            Capsule().fill(BookTheme.gold.opacity(settings.isLLMConfigured && !isTesting ? 1 : 0.5))
                        }
                }
                .buttonStyle(.plain)
                .disabled(!settings.isLLMConfigured || isTesting)

                if let testResult {
                    Text(testResult)
                        .font(BookTheme.captionFont)
                        .foregroundStyle(testSucceeded ? .green : BookTheme.leather)
                        .lineLimit(2)
                }
            }

            Text("支持 \(LLMConnector.supportedSummary)。设置页可同时配置多家 API，切换提供商不会丢失其他 Key。")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BookTheme.selection.opacity(0.35))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(BookTheme.gold.opacity(0.35), lineWidth: 1)
                }
        }
        .onAppear {
            draftAPIKey = settings.apiKey
        }
    }

    private func testConnection() {
        testResult = nil
        isTesting = true
        let configuration = settings.llmConfiguration
        Task {
            do {
                try await LLMService().testConnection(configuration: configuration)
                testSucceeded = true
                testResult = "已连接 \(LLMConnector.displayLabel(provider: configuration.provider, model: configuration.model))"
            } catch {
                testSucceeded = false
                testResult = error.localizedDescription
            }
            isTesting = false
        }
    }
}

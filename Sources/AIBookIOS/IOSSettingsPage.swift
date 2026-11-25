import SwiftUI

/// 设置页。模型、界面语言与阅读风格，对齐 Mac 的 BookSettingsView 三栏内容。
struct IOSSettingsPage: View {
    @ObservedObject var settings: IOSModelSettings
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var localization: IOSLocalizationSettings
    @ObservedObject var styleManager: BookStyleManager
    @State private var selectedTab: Tab = .ai

    /// 与 Mac BookSettingsTab 对应的三栏。
    private enum Tab: String, CaseIterable, Identifiable {
        case ai
        case voice
        case appearance

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .ai: return "settings.tab.ai"
            case .voice: return "settings.tab.voice"
            case .appearance: return "settings.tab.appearance"
            }
        }
    }

    var body: some View {
        let _ = localization.localizationRevision // 分段与表单项跟界面语言
        let _ = styleManager.revision // 外观栏跟风格令牌
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(BookL10n.string(tab.titleKey)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                Form {
                    switch selectedTab {
                    case .ai:
                        aiSection
                    case .voice:
                        voiceSection
                    case .appearance:
                        appearanceSection
                    }
                    helpSection
                }
                .scrollContentBackground(.hidden)
            }
            .background(IOSPaper.page)
            .navigationTitle(BookL10n.string("settings.book"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    IOSBubbleMenu(shell: shell) // 设置页同样用左侧下拉换页
                }
            }
        }
    }

    /// 讲解与翻译模型，与 Mac ai 栏一致。
    private var aiSection: some View {
        Section(BookL10n.string("settings.tab.ai")) {
            Button("DeepSeek") {
                settings.useDeepSeek() // 填上 DeepSeek 的地址和模型
            }
            Text(BookL10n.string("llm.hint.deepseek"))
                .font(.footnote)
                .foregroundStyle(IOSPaper.inkMuted)
            TextField(BookL10n.string("label.provider"), text: $settings.baseURL)
            TextField(BookL10n.string("label.model"), text: $settings.model)
            SecureField(BookL10n.string("llm.optionalAPIKey"), text: $settings.apiKey)
        }
    }

    /// 朗读占位，与 Mac 一样先列出项，完整 TTS 仍跟 Mac 演进。
    private var voiceSection: some View {
        Section(BookL10n.string("settings.tab.voice")) {
            Text(BookL10n.string("speech.pace"))
            Text(BookL10n.string("speech.voice"))
        }
    }

    /// 界面语言与风格预设，对应 Mac appearance 栏。
    private var appearanceSection: some View {
        Section(BookL10n.string("settings.tab.appearance")) {
            IOSLanguageSettingsView(localization: localization)
            IOSStyleSettingsView(styleManager: styleManager, localization: localization)
        }
    }

    /// 说明书与隐私，正文不再用 missingBody 占位。
    private var helpSection: some View {
        Section {
            NavigationLink(BookL10n.string("help.manual")) {
                IOSUserManualView()
            }
            NavigationLink(BookL10n.string("privacy.policy.title")) {
                IOSPrivacyPolicyView()
            }
        }
    }
}
import SwiftUI

/// 读书设置窗：讲解/翻译档案、朗读声音、界面语言与风格。进化 Cursor 不在这里。
struct BookSettingsView: View {
    @EnvironmentObject private var viewModel: ReadingViewModel // 关窗后开说明书走这里，避免叠窗
    @ObservedObject private var settings = AppSettings.shared // 上下文比例等读书偏好
    @ObservedObject private var styleManager = BookStyleManager.shared // revision 变了整窗重绘
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: BookSettingsTab = .ai // 默认先配讲解/翻译，声音和外观后调

    /// 读书设置三栏。
    private enum BookSettingsTab: String, CaseIterable, Identifiable {
        case ai
        case voice
        case appearance

        var id: String { rawValue }

        /// 分段按钮文案。
        var localizedTitle: String {
            switch self {
            case .ai: return BookL10n.string("settings.tab.ai")
            case .voice: return BookL10n.string("settings.tab.voice")
            case .appearance: return BookL10n.string("settings.tab.appearance")
            }
        }

        /// 分段与标题共用 SF Symbol。
        var icon: String {
            switch self {
            case .ai: return "cpu"
            case .voice: return "speaker.wave.2.fill"
            case .appearance: return "paintpalette"
            }
        }

    }

    var body: some View {
        ZStack {
            BookTheme.deskGradient
                .ignoresSafeArea()

            VStack(spacing: 14) {
                header
                tabSwitcher

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case .ai:
                            aiSettingsContent
                        case .voice:
                            voiceSettingsContent
                        case .appearance:
                            settingsSection(title: BookL10n.string("settings.language"), icon: "globe") {
                                BookLanguageSettingsView()
                            }
                            settingsSection(title: BookL10n.string("settings.themePresets"), icon: "paintpalette") {
                                BookStyleSettingsView()
                            }
                        }
                    }
                    .padding(24)
                }
                .bookPage(BookTheme.pageLeft)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(BookTheme.gold.opacity(0.16), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
            }
            .padding(24)
        }
        .frame(width: BookSettingsWindowMetrics.width, height: BookSettingsWindowMetrics.height)
        .id(styleManager.revision)
    }

    /// 顶栏：当前栏图标 + 说明书 + 完成。
    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                    Circle()
                    .fill(BookTheme.chromeOverlay.opacity(0.08))
                    .frame(width: 46, height: 46)
                Image(systemName: selectedTab.icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(BookTheme.goldSoft)
            }

            Text(BookL10n.string("settings.book"))
                .font(BookTheme.titleFont)
                .foregroundStyle(BookTheme.goldSoft)

            Spacer()

            BookActionButton(title: BookL10n.string("action.manual"), icon: "book.pages") {
                dismiss()
                DispatchQueue.main.async {
                    viewModel.openUserManual() // 先 dismiss 再开，避免设置窗挡说明书
                }
            }
            .help(BookL10n.string("help.openManual"))

            BookActionButton(title: BookL10n.string("action.done"), icon: "checkmark", isProminent: true) {
                dismiss()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BookTheme.leatherGradient)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(BookTheme.chromeOverlay.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.32), radius: 16, y: 8)
        }
    }

    /// 三栏切换条，选中走金底。
    private var tabSwitcher: some View {
        HStack(spacing: 10) {
            ForEach(BookSettingsTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BookTheme.menuPanelFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(BookTheme.menuPanelBorder, lineWidth: 1.2)
                }
        }
    }

    /// 单栏按钮；isSelected 决定金底还是菜单底。
    private func tabButton(_ tab: BookSettingsTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = tab
            }
        } label: {
            Label(tab.localizedTitle, systemImage: tab.icon)
                .font(BookTheme.labelFont.weight(.semibold))
                .foregroundStyle(isSelected ? BookTheme.buttonProminentText : BookTheme.menuItemText)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            isSelected
                                ? AnyShapeStyle(BookTheme.goldGradient)
                                : AnyShapeStyle(BookTheme.menuItemFill)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(
                                    isSelected ? BookTheme.menuItemBorderHover : BookTheme.menuItemBorder,
                                    lineWidth: 1.2
                                )
                        }
                }
        }
        .buttonStyle(.plain)
    }

    /// 讲解/翻译档案、目标语言、送模上下文比例。
    private var aiSettingsContent: some View {
        Group {
            settingsSection(title: BookL10n.string("settings.llmProviders"), icon: "sparkles") {
                LLMProfilesSettingsView(scope: .book) // 只编读书档案，进化档案在 SettingsView
            }

            settingsSection(title: BookL10n.string("translation.target.title"), icon: "globe") {
                TranslationLanguageSettingsView()
            }

            settingsSection(title: BookL10n.string("settings.contextPercent"), icon: "text.book.closed") {
                HStack {
                    Text(BookL10n.string("settings.contextPercent"))
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.settingsPrimary)
                    Spacer()
                    Text("\(Int(settings.bookContextPercent))%")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.settingsPrimary)
                }
                Slider(value: $settings.bookContextPercent, in: 10 ... 100, step: 5) // 10% 起，避免几乎不带正文
                    .tint(BookTheme.gold)
            }
        }
    }

    /// 讲解朗读声音整页，不在这里拆控件。
    private var voiceSettingsContent: some View {
        ExplanationVoiceSettingsView()
    }

    /// 一块带标题图标的设置卡片。
    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(BookTheme.labelFont)
                .foregroundStyle(BookTheme.settingsPrimary)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BookTheme.pageRight)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(BookTheme.pageEdge.opacity(0.72), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            }
        }
    }
}

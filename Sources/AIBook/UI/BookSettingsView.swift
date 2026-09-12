import SwiftUI

/// Reading (book) settings: LLM profiles for讲解/翻译 and voice for朗读.
struct BookSettingsView: View {
    @EnvironmentObject private var viewModel: ReadingViewModel
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var styleManager = BookStyleManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: BookSettingsTab = .ai

    private enum BookSettingsTab: String, CaseIterable, Identifiable {
        case ai
        case voice
        case appearance

        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .ai: return BookL10n.string("settings.tab.ai")
            case .voice: return BookL10n.string("settings.tab.voice")
            case .appearance: return BookL10n.string("settings.tab.appearance")
            }
        }

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
                    viewModel.openUserManual()
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

    private var aiSettingsContent: some View {
        Group {
            settingsSection(title: BookL10n.string("settings.llmProviders"), icon: "sparkles") {
                LLMProfilesSettingsView(scope: .book)
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
                Slider(value: $settings.bookContextPercent, in: 10 ... 100, step: 5)
                    .tint(BookTheme.gold)
            }
        }
    }

    private var voiceSettingsContent: some View {
        ExplanationVoiceSettingsView()
    }

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

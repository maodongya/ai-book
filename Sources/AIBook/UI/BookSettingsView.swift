import SwiftUI

/// Reading (book) settings: LLM profiles for讲解/翻译 and voice for朗读.
struct BookSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: BookSettingsTab = .ai

    private enum BookSettingsTab: String, CaseIterable, Identifiable {
        case ai = "AI模型设置"
        case voice = "语音设置"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .ai: return "cpu"
            case .voice: return "speaker.wave.2.fill"
            }
        }

        var subtitle: String {
            switch self {
            case .ai:
                return "读书讲解、翻译与名著补充使用的大模型（推荐本机 Ollama）"
            case .voice:
                return "朗读节奏、语言处理与讲解声音"
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
                        if selectedTab == .ai {
                            aiSettingsContent
                        } else {
                            voiceSettingsContent
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
        .frame(minWidth: 680, minHeight: 560)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 46, height: 46)
                Image(systemName: selectedTab.icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(BookTheme.goldSoft)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("book 设置")
                    .font(BookTheme.titleFont)
                    .foregroundStyle(BookTheme.goldSoft)
                Text(selectedTab.subtitle)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(Color.white.opacity(0.66))
            }

            Spacer()

            BookStatusPill(title: selectedTab.rawValue, icon: selectedTab.icon, tint: Color.white.opacity(0.66))

            BookActionButton(title: "完成", icon: "checkmark", isProminent: true) {
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
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
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
                .fill(Color.white.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
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
            Label(tab.rawValue, systemImage: tab.icon)
                .font(BookTheme.labelFont)
                .foregroundStyle(isSelected ? BookTheme.leatherShadow : BookTheme.goldSoft.opacity(0.78))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(BookTheme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.04)))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(
                                    isSelected ? BookTheme.goldSoft.opacity(0.55) : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        }
                }
        }
        .buttonStyle(.plain)
    }

    private var aiSettingsContent: some View {
        Group {
            settingsSection(title: "大模型 API（多提供商）", icon: "sparkles") {
                LLMProfilesSettingsView(scope: .book)
            }

            settingsSection(title: "原文节选", icon: "text.book.closed") {
                HStack {
                    Text("讲解与追问时附带给模型的左页节选占比")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                    Spacer()
                    Text("\(Int(settings.bookContextPercent))%")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.leather)
                }
                Slider(value: $settings.bookContextPercent, in: 10 ... 100, step: 5)
                    .tint(BookTheme.gold)
            }

            settingsSection(title: "说明", icon: "info.circle") {
                Text("读书助手、讲解、翻译与名著补充均使用此处配置的模型，与 AI 进化互不影响。")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Text("大模型 API 支持 \(LLMConnector.supportedSummary) 等 OpenAI 兼容接口；Ollama 本地默认可不填 Key。")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            }
        }
    }

    private var voiceSettingsContent: some View {
        Group {
            settingsSection(title: "讲解朗读", icon: "waveform") {
                ExplanationVoiceSettingsView()
            }

            settingsSection(title: "关于语音", icon: "music.note") {
                Text("在本页可切换朗读节奏、语言处理策略和讲解声音。")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Text("建议：快速浏览使用「快速 + 高效」，细读讲解使用「舒缓 + 深度」。")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            }
        }
    }

    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(BookTheme.labelFont)
                .foregroundStyle(BookTheme.ink)

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

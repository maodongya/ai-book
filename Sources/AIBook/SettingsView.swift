import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .ai

    private enum SettingsTab: String, CaseIterable, Identifiable {
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
                return "配置大模型、Cursor 本地对话与自我进化"
            case .voice:
                return "调整朗读引擎、语言处理与在线女声"
            }
        }
    }

    var body: some View {
        ZStack {
            BookTheme.deskGradient
                .ignoresSafeArea()

            VStack(spacing: 14) {
                settingsHeader
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

    private var settingsHeader: some View {
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
                Text("系统设置")
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
            ForEach(SettingsTab.allCases) { tab in
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

    private func tabButton(_ tab: SettingsTab) -> some View {
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
                // plain 按钮默认只命中文字/图标；扩展为整块 Tab 区域可点
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
                LLMProfilesSettingsView()
            }

            settingsSection(title: "Cursor 本地对话", icon: "cursorarrow.rays") {
                labeledSecureField("Cursor API Key", text: $settings.cursorAPIKey)
                    .onSubmit {
                        settings.saveCursorAPIKey(settings.cursorAPIKey)
                    }

                HStack(spacing: 8) {
                    Button {
                        settings.saveCursorAPIKey(settings.cursorAPIKey)
                    } label: {
                        Label("保存 Cursor Key", systemImage: "key.fill")
                    }
                    .settingsPillButton(prominent: true)

                    Button {
                        settings.refreshCursorAPIKeyFromSources()
                    } label: {
                        Label("从环境变量读取", systemImage: "arrow.down.doc")
                    }
                    .settingsPillButton()
                }

                if settings.isCursorConfigured {
                    Label("Cursor API Key 已配置", systemImage: "checkmark.circle.fill")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(.green)
                }

                labeledField("Cursor 模型", text: $settings.cursorModel)
                labeledField("Bridge 目录（可选）", text: $settings.cursorBridgePath)

                Text("也可创建 ai-book/cursor.local.env，内容：CURSOR_API_KEY=你的密钥")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Text("或运行：./scripts/setup-cursor-key.sh")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            }

            settingsSection(title: "ai-book 自我进化", icon: "arrow.triangle.2.circlepath") {
                Toggle("自动升级（有待办命令时自动进化并重启）", isOn: $settings.autoEvolutionEnabled)
                    .font(BookTheme.bodyFont)
                Text("开启后，启动 AIBook 时若左页有未完成的编号命令，将自动执行进化、打包安装并继续下一条，无需手动点击「进化」。")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            }

            settingsSection(title: "说明", icon: "info.circle") {
                Text("左页「\(ClassicLiteratureSupplement.capabilityLabel)」可识别名著节选并由大模型补全为完整篇章，自动保存。")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Text("顶栏右侧（AI 进化区）提供「大模型 API」与「Cursor 本地」切换；读书助手讲解与翻译使用同一设置（可在设置中查看）。")
                    .font(BookTheme.bodyFont)
                    .foregroundStyle(BookTheme.inkSecondary)
                Text("大模型 API 支持 \(LLMConnector.supportedSummary) 等 OpenAI 兼容接口。")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                ForEach(LLMConnector.aboutLines, id: \.self) { line in
                    Text(line)
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                }
            }
        }
    }

    private var voiceSettingsContent: some View {
        Group {
            settingsSection(title: "讲解朗读", icon: "waveform") {
                ExplanationVoiceSettingsView()
            }

            settingsSection(title: "关于语音", icon: "music.note") {
                Text("在本页可切换语音引擎、语言处理策略和讲解声音模型。")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Text("建议：低延时使用「极速（本地）+ 高效」，高音质使用「美声（在线）+ 深度」。")
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

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
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
                                .strokeBorder(BookTheme.pageEdge.opacity(0.85), lineWidth: 1)
                        }
                }
        }
    }

    private func labeledSecureField(_ title: String, text: Binding<String>) -> some View {
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
                                .strokeBorder(BookTheme.pageEdge.opacity(0.85), lineWidth: 1)
                        }
                }
        }
    }
}

extension View {
    func settingsPillButton(prominent: Bool = false) -> some View {
        bookPageButton(prominent: prominent)
    }
}

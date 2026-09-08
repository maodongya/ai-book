import SwiftUI

/// Evolution-focused system settings (Cursor, auto-upgrade).
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BookTheme.deskGradient
                .ignoresSafeArea()

            VStack(spacing: 14) {
                settingsHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        evolutionSettingsContent
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
        .frame(minWidth: 680, minHeight: 520)
    }

    private var settingsHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 46, height: 46)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(BookTheme.goldSoft)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("进化设置")
                    .font(BookTheme.titleFont)
                    .foregroundStyle(BookTheme.goldSoft)
                Text("Cursor 本地、自动升级链；读书模型与语音请使用顶栏「book设置」")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(Color.white.opacity(0.66))
            }

            Spacer()

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

    private var evolutionSettingsContent: some View {
        Group {
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
                        settings.reloadCursorAPIKey()
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
                Toggle("自动升级（有待办时自动进化并重启）", isOn: $settings.autoEvolutionEnabled)
                    .font(BookTheme.bodyFont)
                Text("开启后，在本次会话中点击过「进化」且队列仍有待办时，将自动执行进化、打包安装并继续下一条。冷启动不会自动开始。")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Text("模型在 AI 进化页顶栏选择；Cursor Key 与桥接见上方「Cursor 本地对话」。")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            }

            settingsSection(title: "说明", icon: "info.circle") {
                Text("左页「\(ClassicLiteratureSupplement.capabilityLabel)」可识别名著节选并由大模型补全为完整篇章，自动保存。")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Text("读书讲解、翻译与朗读声音在顶栏「book设置」中配置，与进化互不影响。")
                    .font(BookTheme.bodyFont)
                    .foregroundStyle(BookTheme.inkSecondary)
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

import SwiftUI

/// Evolution-focused system settings (Cursor, auto-upgrade).
struct SettingsView: View {
    @EnvironmentObject private var viewModel: ReadingViewModel
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var styleManager = BookStyleManager.shared
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
        .frame(width: BookSettingsWindowMetrics.width, height: BookSettingsWindowMetrics.height)
        .id(styleManager.revision)
    }

    private var settingsHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(BookTheme.chromeOverlay.opacity(0.08))
                    .frame(width: 46, height: 46)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(BookTheme.goldSoft)
            }

            Text("进化设置")
                .font(BookTheme.titleFont)
                .foregroundStyle(BookTheme.goldSoft)

            Spacer()

            BookActionButton(title: "说明书", icon: "book.pages") {
                dismiss()
                DispatchQueue.main.async {
                    viewModel.openUserManual()
                }
            }
            .help("打开 AIBook 功能说明书")

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
                        .strokeBorder(BookTheme.chromeOverlay.opacity(0.10), lineWidth: 1)
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

            }

            settingsSection(title: "ai-book 自我进化", icon: "arrow.triangle.2.circlepath") {
                HStack {
                    Text("自动升级")
                        .font(BookTheme.bodyFont)
                        .foregroundStyle(BookTheme.settingsPrimary)
                    Spacer()
                    Toggle("自动升级", isOn: $settings.autoEvolutionEnabled)
                        .labelsHidden()
                        .tint(BookTheme.gold)
                }
            }
        }
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

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
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
                                .strokeBorder(BookTheme.pageEdge.opacity(0.85), lineWidth: 1)
                        }
                }
        }
    }

    private func labeledSecureField(_ title: String, text: Binding<String>) -> some View {
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

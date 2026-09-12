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

            Text(BookL10n.string("settings.evolution"))
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

    private var evolutionSettingsContent: some View {
        Group {
            settingsSection(title: BookL10n.string("settings.cursorLocal"), icon: "cursorarrow.rays") {
                labeledSecureField("Cursor API Key", text: $settings.cursorAPIKey)
                    .onSubmit {
                        settings.saveCursorAPIKey(settings.cursorAPIKey)
                    }

                HStack(spacing: 8) {
                    Button {
                        settings.saveCursorAPIKey(settings.cursorAPIKey)
                    } label: {
                        Label(BookL10n.string("llm.saveCursorKey"), systemImage: "key.fill")
                    }
                    .settingsPillButton(prominent: true)

                    Button {
                        settings.reloadCursorAPIKey()
                    } label: {
                        Label(BookL10n.string("action.loadFromEnv"), systemImage: "arrow.down.doc")
                    }
                    .settingsPillButton()
                }

                if settings.isCursorConfigured {
                    Label(BookL10n.string("llm.cursorKeyConfigured"), systemImage: "checkmark.circle.fill")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(.green)
                }

                labeledField(BookL10n.string("settings.cursorModel"), text: $settings.cursorModel)
                labeledField(BookL10n.string("settings.bridgeDir"), text: $settings.cursorBridgePath)

            }

            settingsSection(title: BookL10n.string("settings.selfEvolution"), icon: "arrow.triangle.2.circlepath") {
                HStack {
                    Text(BookL10n.string("settings.autoUpgrade"))
                        .font(BookTheme.bodyFont)
                        .foregroundStyle(BookTheme.settingsPrimary)
                    Spacer()
                    Toggle(BookL10n.string("settings.autoUpgrade"), isOn: $settings.autoEvolutionEnabled)
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

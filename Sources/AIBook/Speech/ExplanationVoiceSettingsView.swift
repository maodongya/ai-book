import SwiftUI

struct ExplanationVoiceSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(BookL10n.string("speech.systemVoiceHint"), systemImage: "speaker.wave.2")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.settingsPrimary)

            settingsCard(title: BookL10n.string("speech.pace"), icon: "waveform") {
                Picker(BookL10n.string("speech.pace"), selection: $settings.speechEngineMode) {
                    ForEach(SpeechEngineMode.allCases) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(engineModeDescription)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.settingsSecondary)
            }

            settingsCard(title: BookL10n.string("speech.languageProcessing"), icon: "textformat.alt") {
                Picker(BookL10n.string("speech.languageProcessing"), selection: $settings.speechLanguageMode) {
                    ForEach(SpeechLanguageMode.allCases) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(languageModeDescription)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.settingsSecondary)
            }

            settingsCard(title: BookL10n.string("speech.voice"), icon: "person.wave.2") {
                Picker(BookL10n.string("speech.voice"), selection: $settings.explanationVoiceID) {
                    ForEach(SpeechVoiceCatalog.groupedSelectableOptions(), id: \.title) { group in
                        Section(group.title) {
                            ForEach(group.voices) { voice in
                                Text("\(voice.displayName) · \(voice.subtitle)")
                                    .tag(voice.id)
                            }
                        }
                    }
                }
                .labelsHidden()

                if let selected = SpeechVoiceCatalog.option(for: settings.explanationVoiceID) {
                    HStack(spacing: 8) {
                        Label(selected.displayName, systemImage: "speaker.wave.2")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.settingsPrimary)
                        Text(selected.genderLabel)
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.settingsSecondary)
                    }
                }

                Button {
                    previewSelectedVoice()
                } label: {
                    Label(BookL10n.string("action.previewVoice"), systemImage: "play.circle.fill")
                }
                .settingsPillButton(prominent: true)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(.green)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(.red)
            }
        }
        .onAppear {
            settings.reloadExplanationVoices()
        }
    }

    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(BookTheme.labelFont)
                .foregroundStyle(BookTheme.settingsPrimary)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BookTheme.menuItemFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(BookTheme.pageEdge.opacity(0.66), lineWidth: 1)
                }
        }
    }

    private var engineModeDescription: String {
        settings.speechEngineMode.localizedDescription
    }

    private var languageModeDescription: String {
        settings.speechLanguageMode.localizedDescription
    }

    private func previewSelectedVoice() {
        errorMessage = nil
        statusMessage = BookL10n.string("speech.preview.running")

        Task {
            do {
                try ExplanationSpeechReader.shared.previewSelectedVoice()
                while ExplanationSpeechReader.shared.isBusy {
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                statusMessage = BookL10n.string("speech.preview.done")
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = nil
            }
        }
    }
}

import SwiftUI

struct ExplanationVoiceSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("使用 macOS 系统语音朗读，无需下载或联网。", systemImage: "speaker.wave.2")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)

            settingsCard(title: "朗读节奏", icon: "waveform") {
                Picker("朗读节奏", selection: $settings.speechEngineMode) {
                    ForEach(SpeechEngineMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(engineModeDescription)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            }

            settingsCard(title: "语言处理", icon: "textformat.alt") {
                Picker("语言处理", selection: $settings.speechLanguageMode) {
                    ForEach(SpeechLanguageMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(languageModeDescription)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            }

            settingsCard(title: "讲解声音", icon: "person.wave.2") {
                Picker("讲解声音", selection: $settings.explanationVoiceID) {
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
                            .foregroundStyle(BookTheme.leather)
                        Text(selected.genderLabel)
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.inkMuted)
                    }
                }

                Button {
                    previewSelectedVoice()
                } label: {
                    Label("试听当前声音", systemImage: "play.circle.fill")
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
                .foregroundStyle(BookTheme.ink)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.42))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(BookTheme.pageEdge.opacity(0.66), lineWidth: 1)
                }
        }
    }

    private var engineModeDescription: String {
        switch settings.speechEngineMode {
        case .fast:
            return "快速：语速较快，适合浏览式收听。"
        case .balanced:
            return "平衡：语速与停顿适中，推荐默认。"
        case .natural:
            return "自然：略慢、咬字更清晰，适合讲解。"
        case .relaxed:
            return "舒缓：语速较慢、停顿更长，适合细读。"
        }
    }

    private var languageModeDescription: String {
        switch settings.speechLanguageMode {
        case .efficient:
            return "语言处理 · 高效：更少改写，切句更长，适合追求速度。"
        case .balanced:
            return "语言处理 · 平衡：速度与表达清晰度均衡，推荐默认。"
        case .deep:
            return "语言处理 · 深度：更短分句、标点停顿、缩写拆读与可读化，减少吞字和长句含混。"
        }
    }

    private func previewSelectedVoice() {
        errorMessage = nil
        statusMessage = "正在试听…"

        Task {
            do {
                try ExplanationSpeechReader.shared.previewSelectedVoice()
                while ExplanationSpeechReader.shared.isBusy {
                    try await Task.sleep(nanoseconds: 200_000_000)
                }
                statusMessage = "试听完成"
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = nil
            }
        }
    }
}

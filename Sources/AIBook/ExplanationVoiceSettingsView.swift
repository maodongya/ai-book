import SwiftUI

struct ExplanationVoiceSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var downloadingVoiceID: String?
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    private var downloadedIDs: Set<String> {
        settings.downloadedNeuralVoiceIDs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("默认推荐美声在线 + 深度语言处理，让朗读更清晰、舒展、耐听。", systemImage: "sparkles")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)

            settingsCard(title: "语音引擎", icon: "waveform") {
                Picker("语音引擎", selection: $settings.speechEngineMode) {
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
                    ForEach(SpeechVoiceCatalog.groupedSelectableOptions(downloadedNeuralIDs: downloadedIDs), id: \.title) { group in
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
                        Label(selected.displayName, systemImage: selected.isNeural ? "cloud.fill" : "speaker.wave.2")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.leather)
                        Text(selected.genderLabel)
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.inkMuted)
                        if selected.isNeural {
                            Text(SpeechVoiceStore.isDownloaded(selected.id) ? "已下载" : "未下载")
                                .font(BookTheme.captionFont)
                                .foregroundStyle(SpeechVoiceStore.isDownloaded(selected.id) ? .green : .orange)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        previewSelectedVoice()
                    } label: {
                        Label("试听当前声音", systemImage: "play.circle.fill")
                    }
                    .settingsPillButton(prominent: true)

                    if let selected = SpeechVoiceCatalog.option(for: settings.explanationVoiceID), selected.isNeural,
                       !SpeechVoiceStore.isDownloaded(selected.id),
                       settings.speechEngineMode != .fastLocal {
                        Button {
                            downloadVoice(selected)
                        } label: {
                            Label(downloadingVoiceID == selected.id ? "下载中…" : "下载女声模型", systemImage: "icloud.and.arrow.down")
                        }
                        .settingsPillButton()
                        .disabled(downloadingVoiceID != nil)
                    }
                }
            }

            if !SpeechVoiceCatalog.pendingNeuralVoices(downloadedNeuralIDs: downloadedIDs).isEmpty {
                settingsCard(title: "推荐在线女声", icon: "cloud") {
                    ForEach(SpeechVoiceCatalog.pendingNeuralVoices(downloadedNeuralIDs: downloadedIDs)) { voice in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(voice.displayName)
                                    .font(BookTheme.bodyFont)
                                    .foregroundStyle(BookTheme.ink)
                                Text(voice.subtitle)
                                    .font(BookTheme.captionFont)
                                    .foregroundStyle(BookTheme.inkMuted)
                            }
                            Spacer()
                            if settings.speechEngineMode != .fastLocal {
                                Button {
                                    downloadVoice(voice)
                                } label: {
                                    Label(downloadingVoiceID == voice.id ? "下载中…" : "下载", systemImage: "icloud.and.arrow.down")
                                }
                                .settingsPillButton()
                                .disabled(downloadingVoiceID != nil)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
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
        .onChange(of: settings.explanationVoiceID) { _ in
            Task {
                await ExplanationSpeechReader.shared.prewarmCurrentVoice()
            }
        }
        .onChange(of: settings.speechEngineMode) { _ in
            Task {
                await ExplanationSpeechReader.shared.prewarmCurrentVoice()
            }
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
        case .fastLocal:
            return "当前为极速本地模式：首句延迟最低，适合实时朗读与跟读。"
        case .balancedNeural:
            return "当前为平衡在线模式：在线神经语音，速度与音质均衡。"
        case .neuralQuality:
            return "当前为高音质在线模式：采用更高码率神经语音，音色更细腻。"
        case .studioBeauty:
            return "当前为美声在线模式：高码率 + 慢速咬字 + 动态韵律停顿，尽量做到字正腔圆、婉转动听。"
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

    private func downloadVoice(_ voice: SpeechVoiceOption) {
        errorMessage = nil
        statusMessage = nil
        downloadingVoiceID = voice.id

        Task {
            do {
                try await SpeechVoiceDownloader.download(voice: voice)
                await MainActor.run {
                    settings.reloadExplanationVoices()
                    settings.explanationVoiceID = voice.id
                    downloadingVoiceID = nil
                    statusMessage = "已下载「\(voice.displayName)」并设为当前讲解声音。"
                }
            } catch {
                await MainActor.run {
                    downloadingVoiceID = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

import Foundation

enum EdgeTTSService {
    struct NeuralProsody {
        let rate: String
        let pitch: String
        let volume: String
    }

    enum NeuralAudioProfile {
        case fast
        case balanced
        case studio
        case beauty

        var outputFormatCode: String {
            switch self {
            case .fast:
                return "AUDIO_16KHZ_32KBITRATE_MONO_MP3"
            case .balanced:
                return "AUDIO_24KHZ_48KBITRATE_MONO_MP3"
            case .studio:
                return "AUDIO_24KHZ_96KBITRATE_MONO_MP3"
            case .beauty:
                return "AUDIO_24KHZ_96KBITRATE_MONO_MP3"
            }
        }

        var prosody: NeuralProsody? {
            switch self {
            case .fast:
                return NeuralProsody(rate: "+10%", pitch: "+0Hz", volume: "+0%")
            case .balanced:
                return NeuralProsody(rate: "+0%", pitch: "+0Hz", volume: "+0%")
            case .studio:
                return NeuralProsody(rate: "-8%", pitch: "+10Hz", volume: "+6%")
            case .beauty:
                return NeuralProsody(rate: "-18%", pitch: "+16Hz", volume: "+8%")
            }
        }
    }

    enum ServiceError: LocalizedError {
        case emptyText
        case bridgeUnavailable(String)

        var errorDescription: String? {
            switch self {
            case .emptyText:
                return "语音合成文本为空。"
            case .bridgeUnavailable(let message):
                return message
            }
        }
    }

    static func synthesize(
        text: String,
        voiceID: String,
        profile: NeuralAudioProfile = .balanced,
        prosodyOverride: NeuralProsody? = nil
    ) async throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ServiceError.emptyText }
        let resolvedProsody = prosodyOverride ?? profile.prosody

        do {
            return try await SpeechBridgeService.synthesize(
                text: trimmed,
                voiceID: voiceID,
                outputFormat: profile.outputFormatCode,
                prosody: resolvedProsody.map { ($0.rate, $0.pitch, $0.volume) }
            )
        } catch let error as SpeechBridgeService.BridgeError {
            throw ServiceError.bridgeUnavailable(error.localizedDescription)
        } catch {
            throw ServiceError.bridgeUnavailable(error.localizedDescription)
        }
    }
}

enum SpeechVoiceDownloader {
    private static let sampleText = "你好，我是 AIBook 讲解助手。愿用字正腔圆、婉转动听的声音，陪你慢慢读书。"

    static func download(voice: SpeechVoiceOption) async throws {
        guard voice.isNeural else { return }

        let audio = try await EdgeTTSService.synthesize(
            text: sampleText,
            voiceID: voice.id,
            profile: .beauty
        )
        guard audio.count >= SpeechVoiceCatalog.minimumNeuralSampleBytes else {
            throw EdgeTTSService.ServiceError.bridgeUnavailable(
                "「\(voice.displayName)」合成失败（返回空音频），该模型可能已从 Edge TTS 下线。"
            )
        }
        let directory = SpeechVoiceStore.voiceDirectory(for: voice.id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try audio.write(to: SpeechVoiceStore.sampleFileURL(for: voice.id), options: .atomic)

        let manifest = """
        {"id":"\(voice.id)","name":"\(voice.displayName)","downloadedAt":"\(ISO8601DateFormatter().string(from: Date()))"}
        """
        try manifest.data(using: .utf8)?.write(to: directory.appendingPathComponent("manifest.json"), options: .atomic)

        SpeechVoiceStore.markDownloaded(voice.id)
    }
}

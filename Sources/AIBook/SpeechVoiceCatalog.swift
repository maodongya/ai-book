import AVFoundation
import Foundation

struct SpeechVoiceOption: Identifiable, Codable, Equatable, Hashable {
    enum Source: String, Codable {
        case system
        case neural
    }

    let id: String
    let displayName: String
    let subtitle: String
    let source: Source
    let genderLabel: String
    let requiresDownload: Bool

    var isNeural: Bool { source == .neural }
}

enum SpeechVoiceCatalog {
    static let defaultNeuralVoiceID = "zh-CN-XiaoyiNeural"

    /// 在线神经网络女声（Microsoft Edge TTS）。仅保留当前 Edge 仍可用、合成非空的音色。
    static let neuralFemaleVoices: [SpeechVoiceOption] = [
        option("zh-CN-XiaoyiNeural", "晓伊", "字正腔圆 · 美声推荐", "女"),
        option("zh-CN-XiaoxiaoNeural", "晓晓", "温柔女声", "女"),
        option("zh-CN-liaoning-XiaobeiNeural", "晓北", "东北方言女声", "女"),
        option("zh-CN-shaanxi-XiaoniNeural", "晓妮", "陕西方言女声", "女"),
        option("zh-HK-HiuGaaiNeural", "晓佳", "粤语女声", "女"),
        option("zh-HK-HiuMaanNeural", "晓曼", "粤语自然女声", "女"),
        option("zh-TW-HsiaoChenNeural", "晓臻", "台湾温柔女声", "女"),
        option("zh-TW-HsiaoYuNeural", "晓雨", "台湾自然女声", "女"),
    ]

    /// 已下线或 Edge 合成返回空音频的神经网络 ID（用于清理旧下载记录）。
    static let retiredNeuralVoiceIDs: Set<String> = [
        "zh-CN-XiaohanNeural",
        "zh-CN-XiaomengNeural",
        "zh-CN-XiaomoNeural",
        "zh-CN-XiaoruiNeural",
        "zh-CN-XiaoshuangNeural",
    ]

    static let minimumNeuralSampleBytes = 512

    static func allOptions() -> [SpeechVoiceOption] {
        systemChineseVoices() + neuralFemaleVoices
    }

    static func option(for id: String) -> SpeechVoiceOption? {
        allOptions().first { $0.id == id }
    }

    static func systemChineseVoices() -> [SpeechVoiceOption] {
        let all = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") }
        let highQuality = all.filter { $0.quality == .enhanced || $0.quality == .premium }
        let candidates = highQuality.isEmpty ? all : highQuality

        return candidates
            .filter { AVSpeechSynthesisVoice(identifier: $0.identifier) != nil }
            .map { voice in
                SpeechVoiceOption(
                    id: voice.identifier,
                    displayName: voice.name,
                    subtitle: "系统语音 · \(voice.language)",
                    source: .system,
                    genderLabel: genderLabel(for: voice),
                    requiresDownload: false
                )
            }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    static func groupedSelectableOptions(downloadedNeuralIDs: Set<String>) -> [(title: String, voices: [SpeechVoiceOption])] {
        var groups: [(String, [SpeechVoiceOption])] = []

        let systemFemales = systemChineseVoices().filter { $0.genderLabel == "女" }
        if !systemFemales.isEmpty {
            groups.append(("系统女声", systemFemales))
        }

        let systemOthers = systemChineseVoices().filter { $0.genderLabel != "女" }
        if !systemOthers.isEmpty {
            groups.append(("系统其他中文语音", systemOthers))
        }

        let downloaded = neuralFemaleVoices.filter {
            downloadedNeuralIDs.contains($0.id) && SpeechVoiceStore.hasValidNeuralSample($0.id)
        }
        if !downloaded.isEmpty {
            groups.append(("已下载在线女声", downloaded))
        }

        return groups
    }

    static func pendingNeuralVoices(downloadedNeuralIDs: Set<String>) -> [SpeechVoiceOption] {
        neuralFemaleVoices.filter { !downloadedNeuralIDs.contains($0.id) }
    }

    private static func option(_ id: String, _ name: String, _ subtitle: String, _ gender: String) -> SpeechVoiceOption {
        SpeechVoiceOption(
            id: id,
            displayName: name,
            subtitle: subtitle,
            source: .neural,
            genderLabel: gender,
            requiresDownload: true
        )
    }

    private static func genderLabel(for voice: AVSpeechSynthesisVoice) -> String {
        switch voice.gender {
        case .female:
            return "女"
        case .male:
            return "男"
        case .unspecified:
            return "—"
        @unknown default:
            return "—"
        }
    }
}

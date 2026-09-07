import AVFoundation
import Foundation

struct SpeechVoiceOption: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let displayName: String
    let subtitle: String
    let genderLabel: String
}

enum SpeechVoiceCatalog {
    static func allOptions() -> [SpeechVoiceOption] {
        systemChineseVoices()
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
                    genderLabel: genderLabel(for: voice)
                )
            }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    static func groupedSelectableOptions() -> [(title: String, voices: [SpeechVoiceOption])] {
        var groups: [(String, [SpeechVoiceOption])] = []

        let females = systemChineseVoices().filter { $0.genderLabel == "女" }
        if !females.isEmpty {
            groups.append(("女声", females))
        }

        let others = systemChineseVoices().filter { $0.genderLabel != "女" }
        if !others.isEmpty {
            groups.append(("其他中文语音", others))
        }

        return groups
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

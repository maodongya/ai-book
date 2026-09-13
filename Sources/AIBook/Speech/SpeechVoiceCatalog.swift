import AVFoundation
import Foundation

/// 一条可选讲解语音：系统 identifier + 给人看的名字/性别。
struct SpeechVoiceOption: Identifiable, Codable, Equatable, Hashable {
    let id: String // AVSpeechSynthesisVoice.identifier
    let displayName: String
    let subtitle: String
    let genderLabel: String // 「女」/「男」/「—」，分组用
}

/// 本机中文系统语音目录。在线音色不再出现。
enum SpeechVoiceCatalog {
    /// 设置页全部可选项，目前等于系统中文声。
    static func allOptions() -> [SpeechVoiceOption] {
        systemChineseVoices()
    }

    static func option(for id: String) -> SpeechVoiceOption? {
        allOptions().first { $0.id == id }
    }

    /// 中文声：有增强/高级则只用它们，并丢掉 identifier 已失效的。
    static func systemChineseVoices() -> [SpeechVoiceOption] {
        let all = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") }
        let highQuality = all.filter { $0.quality == .enhanced || $0.quality == .premium }
        let candidates = highQuality.isEmpty ? all : highQuality // 没有高品质时退回全部中文

        return candidates
            .filter { AVSpeechSynthesisVoice(identifier: $0.identifier) != nil } // 未下载的丢掉
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

    /// 设置页分组：女声优先单独一组。
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
            return "—" // 系统没标性别
        @unknown default:
            return "—"
        }
    }
}

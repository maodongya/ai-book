import AVFoundation
import SwiftUI

/// 朗读语速。与 Mac 共用 `aiBook.speechEngineMode`。
struct IOSVoiceSettingsView: View {
    @AppStorage("aiBook.speechEngineMode") private var engineModeRaw = SpeechEngineMode.balanced.rawValue
    @AppStorage("aiBook.ios.speechRate") private var speechRate = 0.5
    @AppStorage("aiBook.ios.speakAfterGeneration") private var speakAfterGeneration = false

    private var engineMode: SpeechEngineMode {
        get { SpeechEngineMode.migrated(from: engineModeRaw) }
        nonmutating set { engineModeRaw = newValue.rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(BookL10n.string("speech.pace"), selection: Binding(
                get: { engineMode },
                set: { engineModeRaw = $0.rawValue }
            )) {
                ForEach(SpeechEngineMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Text(BookL10n.string("speech.voice"))
                .font(.subheadline.weight(.semibold))
            Slider(value: $speechRate, in: 0.35...0.65, step: 0.05)
            Text(String(format: "%.0f%%", speechRate * 100))
                .font(.caption)
                .foregroundStyle(IOSPaper.inkMuted)

            Toggle(isOn: $speakAfterGeneration) {
                Text(BookL10n.string("menu.speech"))
                    .font(.subheadline)
            }
        }
    }
}

/// 与 Mac 落盘一致的语速档。
enum SpeechEngineMode: String, CaseIterable, Identifiable {
    case fast = "快速"
    case balanced = "平衡"
    case natural = "自然"
    case relaxed = "舒缓"

    var id: String { rawValue }

    static func migrated(from stored: String?) -> SpeechEngineMode {
        guard let stored, !stored.isEmpty else { return .balanced }
        return SpeechEngineMode(rawValue: stored) ?? .balanced
    }

    var rateMultiplier: Float {
        switch self {
        case .fast: return 0.58
        case .balanced: return 0.5
        case .natural: return 0.45
        case .relaxed: return 0.4
        }
    }
}
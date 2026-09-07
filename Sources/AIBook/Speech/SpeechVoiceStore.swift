import AVFoundation
import Foundation

enum SpeechVoiceStore {
    private static let selectedKey = "aiBook.explanationVoiceID"

    static var selectedVoiceID: String {
        get {
            if let stored = UserDefaults.standard.string(forKey: selectedKey), !stored.isEmpty {
                return stored
            }
            return defaultVoiceID ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: selectedKey)
        }
    }

    static var defaultVoiceID: String? {
        systemChineseVoices().first(where: { $0.genderLabel == "女" })?.id
            ?? systemChineseVoices().first?.id
    }

    static func isReadyForUse(_ option: SpeechVoiceOption) -> Bool {
        AVSpeechSynthesisVoice(identifier: option.id) != nil
    }

    static func resolvedVoiceForSpeaking() -> SpeechVoiceOption? {
        if let selected = SpeechVoiceCatalog.option(for: selectedVoiceID),
           isReadyForUse(selected) {
            return selected
        }

        if let female = SpeechVoiceCatalog.systemChineseVoices().first(where: {
            $0.genderLabel == "女" && isReadyForUse($0)
        }) {
            return female
        }

        return SpeechVoiceCatalog.systemChineseVoices().first { isReadyForUse($0) }
    }

    /// 若曾保存在线音色 ID，迁移到可用的系统语音。
    static func normalizeStoredSelection() {
        guard let selected = SpeechVoiceCatalog.option(for: selectedVoiceID),
              isReadyForUse(selected) else {
            if let fallback = defaultVoiceID {
                selectedVoiceID = fallback
            }
            return
        }
    }

    private static func systemChineseVoices() -> [SpeechVoiceOption] {
        SpeechVoiceCatalog.systemChineseVoices()
    }
}

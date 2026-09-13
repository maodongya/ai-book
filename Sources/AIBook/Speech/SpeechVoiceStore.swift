import AVFoundation
import Foundation

/// 讲解朗读选中的系统语音。在线音色已废弃，读盘时迁回可用系统声。
enum SpeechVoiceStore {
    /// 选中语音 id 的键，只在这里出现。
    private static let selectedKey = "aiBook.explanationVoiceID"

    /// 当前选中的 identifier；空或缺失则用默认女声。
    static var selectedVoiceID: String {
        get {
            if let stored = UserDefaults.standard.string(forKey: selectedKey), !stored.isEmpty {
                return stored
            }
            return defaultVoiceID ?? "" // 本机没有中文声时给空，调用方再守
        }
        set {
            UserDefaults.standard.set(newValue, forKey: selectedKey)
        }
    }

    /// 默认：系统中文女声，没有女声就第一支中文。
    static var defaultVoiceID: String? {
        systemChineseVoices().first(where: { $0.genderLabel == "女" })?.id
            ?? systemChineseVoices().first?.id
    }

    /// 这支声音现在能不能拿来合成（未下载的 identifer 会失败）。
    static func isReadyForUse(_ option: SpeechVoiceOption) -> Bool {
        AVSpeechSynthesisVoice(identifier: option.id) != nil
    }

    /// 真正开读前再解析：选中可用 → 中文女声 → 任一可用中文。
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
                selectedVoiceID = fallback // 旧在线 id 或已删的声
            }
            return
        }
    }

    private static func systemChineseVoices() -> [SpeechVoiceOption] {
        SpeechVoiceCatalog.systemChineseVoices() // 目录是唯一来源
    }
}

import AVFoundation
import Foundation

enum SpeechVoiceStore {
    private static let selectedKey = "aiBook.explanationVoiceID"
    private static let downloadedKey = "aiBook.downloadedNeuralVoiceIDs"

    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("AIBook/voices", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func voiceDirectory(for voiceID: String) -> URL {
        supportDirectory.appendingPathComponent(voiceID, isDirectory: true)
    }

    static var selectedVoiceID: String {
        get {
            if let stored = UserDefaults.standard.string(forKey: selectedKey), !stored.isEmpty {
                return stored
            }
            return SpeechVoiceCatalog.defaultNeuralVoiceID
        }
        set {
            UserDefaults.standard.set(newValue, forKey: selectedKey)
        }
    }

    static var downloadedNeuralVoiceIDs: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: downloadedKey) ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue).sorted(), forKey: downloadedKey)
        }
    }

    static func isDownloaded(_ voiceID: String) -> Bool {
        downloadedNeuralVoiceIDs.contains(voiceID)
    }

    static func markDownloaded(_ voiceID: String) {
        var ids = downloadedNeuralVoiceIDs
        ids.insert(voiceID)
        downloadedNeuralVoiceIDs = ids
    }

    static func sampleFileURL(for voiceID: String) -> URL {
        voiceDirectory(for: voiceID).appendingPathComponent("sample.mp3")
    }

    static func neuralSampleByteCount(for voiceID: String) -> Int? {
        let path = sampleFileURL(for: voiceID).path
        guard FileManager.default.fileExists(atPath: path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? NSNumber
        else { return nil }
        return size.intValue
    }

    static func hasValidNeuralSample(_ voiceID: String) -> Bool {
        guard let bytes = neuralSampleByteCount(for: voiceID) else { return false }
        return bytes >= SpeechVoiceCatalog.minimumNeuralSampleBytes
    }

    static func isReadyForUse(_ option: SpeechVoiceOption) -> Bool {
        switch option.source {
        case .system:
            return AVSpeechSynthesisVoice(identifier: option.id) != nil
        case .neural:
            return isDownloaded(option.id) && hasValidNeuralSample(option.id)
        }
    }

    /// 移除已下线模型与无效样本，避免 Picker 中出现无法试听的条目。
    static func purgeInvalidNeuralDownloads() {
        var ids = downloadedNeuralVoiceIDs
        var changed = false

        for voiceID in ids {
            let catalogMissing = !SpeechVoiceCatalog.neuralFemaleVoices.contains { $0.id == voiceID }
            let retired = SpeechVoiceCatalog.retiredNeuralVoiceIDs.contains(voiceID)
            let invalidSample = !hasValidNeuralSample(voiceID)

            guard catalogMissing || retired || invalidSample else { continue }

            ids.remove(voiceID)
            changed = true
            try? FileManager.default.removeItem(at: voiceDirectory(for: voiceID))
        }

        if changed {
            downloadedNeuralVoiceIDs = ids
        }
    }

    static func resolvedVoiceForSpeaking() -> SpeechVoiceOption? {
        // Always prefer female voice model for explanation/read-aloud.
        if let selected = SpeechVoiceCatalog.option(for: selectedVoiceID),
           selected.genderLabel == "女",
           isReadyForUse(selected) {
            return selected
        }

        if let neuralFemale = SpeechVoiceCatalog.neuralFemaleVoices.first(where: { isReadyForUse($0) }) {
            return neuralFemale
        }

        if let systemFemale = SpeechVoiceCatalog.systemChineseVoices().first(where: {
            $0.genderLabel == "女" && isReadyForUse($0)
        }) {
            return systemFemale
        }

        if let selected = SpeechVoiceCatalog.option(for: selectedVoiceID), isReadyForUse(selected) {
            return selected
        }
        if let neural = SpeechVoiceCatalog.neuralFemaleVoices.first(where: { isReadyForUse($0) }) {
            return neural
        }
        return SpeechVoiceCatalog.systemChineseVoices().first { isReadyForUse($0) }
    }
}

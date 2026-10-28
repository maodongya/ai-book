import Foundation

/// 发给操作模型的界面快照。没有正文，选区和书库都有上限。
struct OperationContextSnapshot: Equatable, Encodable {
    var fileName: String
    var hasDocumentPath: Bool
    var isDirty: Bool
    var hasSelection: Bool
    var selectionExcerpt: String
    var experienceMode: String
    var paneFocus: String
    var rightPage: String
    var assistantPanel: String
    var explanationLanguage: String
    var translationLanguage: String
    var enabledExplanationLanguages: [String]
    var enabledTranslationLanguages: [String]
    var speech: String
    var isRunning: Bool
    var libraryFiles: [String]
    var libraryTruncated: Bool

    static let selectionExcerptLimit = 80 // 只给模型看开头
    static let libraryFileLimit = 40 // 书库名单截断

    /// 从当前界面收一份短快照。调用方不要把正文传进来。
    static func make(
        fileName: String,
        hasDocumentPath: Bool,
        isDirty: Bool,
        selection: String,
        experienceMode: ReadingExperienceMode,
        paneFocus: LearningPaneFocus,
        rightPage: RightPageTab,
        assistantPanel: ReadingAssistantPanel,
        explanationLanguage: TranslationTargetLanguage,
        translationLanguage: TranslationTargetLanguage,
        enabledExplanationLanguages: [TranslationTargetLanguage],
        enabledTranslationLanguages: [TranslationTargetLanguage],
        speech: OperationSpeechState,
        isRunning: Bool,
        libraryFileNames: [String]
    ) -> OperationContextSnapshot {
        let trimmedSelection = selection.trimmingCharacters(in: .whitespacesAndNewlines) // 空白选区当没有
        let excerpt = String(trimmedSelection.prefix(selectionExcerptLimit)) // 第 81 个字符起不进快照
        let library = Array(libraryFileNames.prefix(libraryFileLimit)) // 保持原顺序
        return OperationContextSnapshot(
            fileName: fileName,
            hasDocumentPath: hasDocumentPath,
            isDirty: isDirty,
            hasSelection: !trimmedSelection.isEmpty,
            selectionExcerpt: excerpt,
            experienceMode: experienceMode.rawValue,
            paneFocus: paneFocus.rawValue,
            rightPage: rightPage == .aiEvolution ? "evolution" : "assistant", // 右页只分这两档
            assistantPanel: assistantPanel.rawValue,
            explanationLanguage: explanationLanguage.rawValue,
            translationLanguage: translationLanguage.rawValue,
            enabledExplanationLanguages: enabledExplanationLanguages.map(\.rawValue),
            enabledTranslationLanguages: enabledTranslationLanguages.map(\.rawValue),
            speech: speech.rawValue,
            isRunning: isRunning,
            libraryFiles: library,
            libraryTruncated: libraryFileNames.count > libraryFileLimit
        )
    }

    /// 放进用户消息的 JSON。
    func jsonString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys] // 同样的快照得到同样的字符串
        guard let data = try? encoder.encode(self) else { return "{}" } // 编码失败给空对象，避免把正文塞回去
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

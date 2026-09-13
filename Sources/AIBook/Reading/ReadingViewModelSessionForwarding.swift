import Foundation

// MARK: - 会话 API 转发（保持 UI 仍通过 ReadingViewModel 访问）

extension ReadingViewModel {
    var fileContent: String {
        get { document.fileContent }
        set { document.fileContent = newValue }
    }

    var selectedText: String {
        get { document.selectedText }
        set { document.selectedText = newValue }
    }

    var lessonPlanContent: String {
        get { translation.lessonPlanContent }
        set { translation.lessonPlanContent = newValue }
    }

    var readingAssistantPanel: ReadingAssistantPanel {
        get { assistant.readingAssistantPanel }
        set { assistant.readingAssistantPanel = newValue }
    }

    var explanationSelectionText: String {
        get { assistant.explanationSelectionText }
        set { assistant.explanationSelectionText = newValue }
    }

    var translationTableViewEnabled: Bool {
        get { translation.translationTableViewEnabled }
        set { translation.translationTableViewEnabled = newValue }
    }

    var chatMessages: [ChatMessage] {
        get { assistant.chatMessages }
        set { assistant.chatMessages = newValue }
    }

    var effectiveSelectedText: String {
        let live = document.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return document.lastCommittedSelectionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var effectiveLessonPlanSelectedText: String {
        let live = translation.lessonPlanSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return document.lastCommittedLessonPlanSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var effectiveExplanationPanelSelectedText: String {
        let live = assistant.explanationPanelSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return document.lastCommittedExplanationPanelSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canReadAloud: Bool {
        !effectiveSelectedText.isEmpty
            || !fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || assistant.isSpeakingExplanation
    }

    func sendChatInput() {
        translation.sendChatInput()
    }

    func sendEvolutionChatInput() {
        evolution.sendEvolutionChatInput()
    }

    func generateLessonPlan() {
        translation.generateLessonPlan()
    }

    func refineLessonPlan(instruction: String? = nil) {
        translation.refineLessonPlan(instruction: instruction)
    }

    func handleSourceTextScroll(visibleRange: NSRange) {
        translation.handleSourceTextScroll(visibleRange: visibleRange)
    }

    func lockTranslationAlignment() {
        translation.lockTranslationAlignment()
    }

    func unlockTranslationAlignment() {
        translation.unlockTranslationAlignment()
    }

    func splitTranslationTableBlock(
        id: UUID,
        translationBefore: String,
        translationAfter: String
    ) {
        translation.splitTranslationTableBlock(
            id: id,
            translationBefore: translationBefore,
            translationAfter: translationAfter
        )
    }
}

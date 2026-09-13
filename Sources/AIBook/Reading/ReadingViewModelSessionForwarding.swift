import Foundation

// MARK: - 会话 API 转发（保持 UI 仍通过 ReadingViewModel 访问）

/// 旧 UI 仍通过 `ReadingViewModel` 访问的字段与方法，转发到各 Session。这里不实现产品规则。
extension ReadingViewModel {
    /// 转给文档会话的正文。
    var fileContent: String {
        get { document.fileContent }
        set { document.fileContent = newValue } // 写左页正文，会话各自落盘
    }

    /// 转给助手的左页选区。
    var selectedText: String {
        get { document.selectedText }
        set { document.selectedText = newValue }
    }

    /// 转给助手的教案正文。
    var lessonPlanContent: String {
        get { translation.lessonPlanContent }
        set { translation.lessonPlanContent = newValue } // 右页译文，不进 document
    }

    /// 转给助手的讲解/翻译分栏。
    var readingAssistantPanel: ReadingAssistantPanel {
        get { assistant.readingAssistantPanel }
        set { assistant.readingAssistantPanel = newValue }
    }

    /// 转给助手的讲解面板选区。
    var explanationSelectionText: String {
        get { assistant.explanationSelectionText }
        set { assistant.explanationSelectionText = newValue }
    }

    /// 转给翻译会话的对照表开关。
    var translationTableViewEnabled: Bool {
        get { translation.translationTableViewEnabled }
        set { translation.translationTableViewEnabled = newValue }
    }

    /// 转给助手的聊天记录。
    var chatMessages: [ChatMessage] {
        get { assistant.chatMessages }
        set { assistant.chatMessages = newValue }
    }

    /// 当前选区；松手后的 lastCommitted 作退路，避免滚动时选区被清空。
    var effectiveSelectedText: String {
        let live = document.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return document.lastCommittedSelectionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 译文表里的选区，同样优先 live。
    var effectiveLessonPlanSelectedText: String {
        let live = translation.lessonPlanSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return document.lastCommittedLessonPlanSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 讲解气泡里的选区。
    var effectiveExplanationPanelSelectedText: String {
        let live = assistant.explanationPanelSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return document.lastCommittedExplanationPanelSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 有选区、有全文、或正在朗读都可以点朗读。
    var canReadAloud: Bool {
        !effectiveSelectedText.isEmpty
            || !fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || assistant.isSpeakingExplanation
    }

    /// 右页输入条发送。真正拼提示在 translation。
    func sendChatInput() {
        translation.sendChatInput()
    }

    /// 进化输入条发送。空串直接回。
    func sendEvolutionChatInput() {
        evolution.sendEvolutionChatInput()
    }

    /// 按当前原文出译文。
    func generateLessonPlan() {
        translation.generateLessonPlan()
    }

    /// instruction 空则按默认「改得更通顺」。
    func refineLessonPlan(instruction: String? = nil) {
        translation.refineLessonPlan(instruction: instruction)
    }

    /// 左页滚动，推给对齐同步。
    func handleSourceTextScroll(visibleRange: NSRange) {
        translation.handleSourceTextScroll(visibleRange: visibleRange)
    }

    /// 锁对齐：禁止整体重排，单行仍可改。
    func lockTranslationAlignment() {
        translation.lockTranslationAlignment()
    }

    /// 解锁。原文变过会标 stale。
    func unlockTranslationAlignment() {
        translation.unlockTranslationAlignment()
    }

    /// 对照表一行拆成两行。切割点由 UI 传入两段译文。
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

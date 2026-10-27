import AIBookEvolution
import AppKit
import Combine
import Foundation

@MainActor
/// 读书助手会话：讲解/名著补充、对话消息、朗读与输入框。
final class ReadingAssistantSession: ObservableObject {
    unowned var host: ReadingViewModel!  // VM 注入


    /// 新会话第一条助手欢迎，写入聊天记录。
    static var defaultWelcomeMessage: ChatMessage {
        ChatMessage(role: .assistant, content: ReadingAssistant.welcomeMessage)  // 当前语言欢迎语
    }

    @Published var chatMessages: [ChatMessage] = [] {  // 当前 Tab 上屏列表
        didSet { host.persistChatSession() }  // 气泡变就落盘
    }
    @Published var readingChatInput = "" {  // 右页输入
        didSet { host.persistChatSession() }  // 气泡变就落盘
    }
    @Published var readingAssistantPanel: ReadingAssistantPanel = .explanation {  // 讲解/译文子栏
        didSet {
            guard !host.isRestoringSession else { return }  // 恢复时不反复写
            host.persistChatSession()  // 记住子栏
        }
    }
    @Published var readingAssistantActiveTask: ReadingAssistantPanel?  // 顶栏「讲解中/翻译中」
    @Published var explanationSelectionText = ""  // 讲解全文（给复制/朗读）
    @Published var explanationPanelSelectedText = ""  // 讲解区即时选区

    /// 讲解区选区。空则清 lastCommitted。
    func updateExplanationPanelSelection(_ text: String, range: NSRange? = nil) {
        host.document.updateExplanationPanelSelection(text, range: range)  // 转文档，提交 lastCommitted
    }

    /// 译文选区。
    func updateLessonPlanSelection(_ text: String, range: NSRange? = nil) {
        host.document.updateLessonPlanSelection(text, range: range)  // 转文档
    }
    @Published private(set) var explanationSelectAllSignal = UUID()  // 变一次讲解全选

    @Published var showsExplanationProgressSheet = false
    @Published var explanationStreamPreview = ""
    @Published var explanationProgressTitle = ""
    @Published var explanationAlignment: TranslationAlignment? {
        didSet {
            guard !host.isRestoringSession else { return }
            host.persistChatSession()
        }
    }
    @Published var explanationTableViewEnabled = false {
        didSet {
            guard !host.isRestoringSession else { return }
            host.persistChatSession()
        }
    }
    @Published var explanationTableHighlightedBlockID: UUID?
    @Published var explanationTableScrollTargetID: UUID?
    @Published var explanationTableFocusTranslationBlockID: UUID?
    var isApplyingExplanationAlignment = false

    @Published private(set) var isSpeakingExplanation = false  // 朗读中
    @Published private(set) var isExplanationSpeechPaused = false  // 暂停中
    @Published private(set) var currentSpeechSource: SpeechSource?  // 工具栏用来源高亮
    var readingPromptMessages: [ChatMessage] = [ReadingAssistantSession.defaultWelcomeMessage]  // 讲解源历史
    private var speakingRefreshTask: Task<Void, Never>?  // 200ms 刷按钮

    /// 讲解用的选区：面板选区优先，否则左页选区。
    var effectiveSelectedText: String {
        let live = host.document.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)  // 即时选区
        if !live.isEmpty { return live }  // 有就用
        return host.document.lastCommittedSelectionText.trimmingCharacters(in: .whitespacesAndNewlines)  // 点空白后仍能讲/读
    }

    /// 教案编辑器用的选区，和讲解选区分开。
    var effectiveLessonPlanSelectedText: String {
        let live = host.translation.lessonPlanSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)  // 译文即时
        if !live.isEmpty { return live }  // 有就用
        return host.document.lastCommittedLessonPlanSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)  // 提交值
    }

    /// 讲解面板里高亮的原文，供插入引用。
    var effectiveExplanationPanelSelectedText: String {
        let live = explanationPanelSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)  // 讲解即时
        if !live.isEmpty { return live }  // 有就用
        return host.document.lastCommittedExplanationPanelSelectedText.trimmingCharacters(in: .whitespacesAndNewlines)  // 提交值
    }

    /// 有可读正文且没在跑其它任务才能朗读。
    var canReadAloud: Bool {
        !effectiveSelectedText.isEmpty  // 有选区就能读
            || !host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 没选区读全文
    }

    /// 讲解区已有非欢迎正文。
    var hasExplanationContent: Bool {
        readingPromptMessages.contains { message in  // 有非欢迎助手句才算有讲解
            message.role == .assistant && !isReadingWelcomeMessage(message)  // 欢迎不能改
        }
    }

    /// 讲解栏要画的消息，过滤掉翻译过程。
    var explanationDisplayMessages: [ChatMessage] {
        chatMessages.filter { shouldDisplayInExplanationPanel($0) }  // 去掉用户句和指令气泡
    }



    /// 切讲解/翻译栏并记住。
    func selectReadingAssistantPanel(_ panel: ReadingAssistantPanel) {
        guard readingAssistantPanel != panel else { return }  // 同栏不重入
        readingAssistantPanel = panel  // didSet 落盘
    }


    /// 就地改气泡正文，不重发请求。
    func updateAssistantMessage(id: UUID, content: String) {
        guard let index = chatMessages.firstIndex(where: { $0.id == id && $0.role == .assistant }) else {  // 只改助手
            return  // 不换文再读
        }
        guard chatMessages[index].content != content else { return }  // 没改不写

        host.updatePromptMessage(id: id, content: content)  // 源历史也改
        var updated = chatMessages  // 整表替换触发 Published
        updated[index].content = content  // 只改正文
        chatMessages = updated  // 上屏
    }


    /// 只有助手消息能改。
    func canEditExplanationMessage(_ message: ChatMessage) -> Bool {
        message.role == .assistant && !isReadingWelcomeMessage(message)  // 欢迎不能改
    }


    /// 删一条。欢迎语不能删。
    func deleteChatMessage(id: UUID) {
        guard !host.isRunning else { return }  // 跑着不删，避免历史被拆
        let context = host.activePromptContext  // 当前 Tab
        let messages = host.contextHistory(for: context)  // 源历史
        guard let message = messages.first(where: { $0.id == id }) else { return }  // 已经没了
        let welcomeID = context == .reading  // 欢迎 id 两套
            ? ReadingAssistantSession.defaultWelcomeMessage.id  // 讲解欢迎
            : ReadingEvolutionSession.defaultEvolutionWelcomeMessage.id  // 进化欢迎
        guard messages.count > 1 || message.id != welcomeID else { return }  // 只剩欢迎不能删

        if message.role == .assistant, isSpeakingExplanation {  // 正在读这条就停
            host.assistant.stopExplanationSpeech()  // 当停止
        }

        host.removePromptMessage(id: id, from: context)  // 源历史删
        if host.isDisplaying(context) {  // 当前 Tab 才动气泡
            chatMessages.removeAll { $0.id == id }  // 上屏列表
        }
    }


    /// 把这条讲解存成文件。
    func saveAssistantMessage(id: UUID) {
        guard let message = chatMessages.first(where: { $0.id == id && $0.role == .assistant }) else {  // 只存助手
            return  // 不换文再读
        }
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)  // 空也滤
        guard !content.isEmpty else {  // 没内容
            host.errorMessage = BookL10n.string("vm.error.aiOutputEmptySave")  // 顶栏
            return  // 不换文再读
        }

        host.document.exportContent(  // 另存
            content,
            panelTitle: BookL10n.string("vm.panel.saveAIOutput"),
            panelMessage: BookL10n.string("vm.panel.saveAIOutputMsg"),
            suggestedName: host.document.assistantOutputFileName(for: message),
            successPrefix: BookL10n.string("vm.saved.aiOutput")
        )
    }


    /// 朗读这一条。
    func readAssistantMessage(id: UUID) {
        if isSpeakingExplanation {  // 正在读
            host.assistant.stopExplanationSpeech()  // 当停止
            return  // 不换文再读
        }

        guard let message = chatMessages.first(where: { $0.id == id && $0.role == .assistant }) else {  // 只存助手
            return  // 不换文再读
        }
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)  // 空也滤
        guard !content.isEmpty else {  // 没内容
            host.errorMessage = BookL10n.string("vm.error.aiOutputEmptySpeak")  // 空不读
            return  // 不换文再读
        }

        speakExplanation(content, source: .aiReply)  // 记来源
    }


    /// 打开上次保存的讲解文件。
    func openAssistantMessageFile() {
        let panel = NSOpenPanel()  // 打开讲解文件
        panel.title = BookL10n.string("vm.panel.openAIOutput")  // 单条输出
        panel.allowedContentTypes = [.plainText]  // 文本
        panel.allowsMultipleSelection = false  // 一次一条
        panel.canChooseDirectories = false  // 不要目录
        panel.directoryURL = DocumentExporter.lastDirectoryURL  // 上次

        guard panel.runModal() == .OK, let url = panel.url else { return }  // 取消

        do {
            let text = try String(contentsOf: url, encoding: .utf8)  // utf8
                .trimmingCharacters(in: .whitespacesAndNewlines)  // 首尾空
            guard !text.isEmpty else {  // 空文件
                host.errorMessage = BookL10n.string("vm.error.aiOutputOpenEmpty")  // 提示
                return  // 不换文再读
            }
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()  // 记住
            let message = ChatMessage(role: .assistant, content: text)  // 整篇当一条助手
            host.appendDisplayedMessage(message, to: .reading)  // 追加，不清旧对话
            host.errorMessage = nil  // 清错
            host.document.showTransientSaveMessage(BookL10n.format("vm.opened.aiOutput", url.lastPathComponent))  // 提示
        } catch {
            host.errorMessage = BookL10n.format("vm.error.openAIOutput", error.localizedDescription)  // 读失败
        }
    }


    /// 欢迎语和过程气泡的过滤。
    func shouldDisplayInExplanationPanel(_ message: ChatMessage) -> Bool {
        if message.role == .user { return false }  // 用户句不进讲解区
        if isExplanationInstructionMessage(message) { return false }  // 欢迎和过程气泡
        return !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 空内容也不显示
    }


    /// 讲解区可复制全文。
    func explanationTranscriptText() -> String {
        readingPromptMessages  // 源历史
            .filter { shouldDisplayInExplanationPanel($0) }  // 可显示的
            .map { message in  // 导出带角色标记
                "【助手】\n\(message.content)"  // 导入能再拆
            }
            .joined(separator: "\n\n")  // 条之间停顿
    }


    /// 送给 TTS 的讲解，去掉过程。
    func explanationSpeakableText() -> String {
        readingPromptMessages  // 源历史
            .filter { shouldDisplayInExplanationPanel($0) }  // 可显示的
            .map(\.content)  // 朗读不要标记
            .joined(separator: "\n\n")  // 条之间停顿
            .trimmingCharacters(in: .whitespacesAndNewlines)  // 首尾空
    }


    /// 空讲解新档。
    func newExplanationDocument() {
        guard !host.isRunning else { return }  // 跑着不删，避免历史被拆
        host.selectRightPageTab(.readingAssistant)  // 朗读前切助手，按钮状态对得上
        host.assistant.selectReadingAssistantPanel(.explanation)  // 讲解栏
        host.assistant.stopExplanationSpeech()  // 当停止
        readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage]  // 只留欢迎
        chatMessages = readingPromptMessages  // 上屏
        host.assistant.readingChatInput = ""  // 输入框
        explanationSelectionText = ""  // 复制全文空
        explanationPanelSelectedText = ""  // 选区
        host.document.lastCommittedExplanationPanelSelectedText = ""  // 提交值
        clearExplanationTableState()
        host.errorMessage = nil  // 清错
        host.persistChatSession()  // 记住子栏
    }


    /// 清讲解对话，不关原文。
    func clearExplanation() {
        guard !host.isRunning else { return }  // 跑着不删，避免历史被拆
        host.selectRightPageTab(.readingAssistant)  // 朗读前切助手，按钮状态对得上
        host.assistant.selectReadingAssistantPanel(.explanation)  // 讲解栏
        guard hasExplanationContent else { return }  // 只有欢迎不必清
        host.assistant.stopExplanationSpeech()  // 当停止
        readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage]  // 只留欢迎
        chatMessages = readingPromptMessages  // 上屏
        host.assistant.readingChatInput = ""  // 输入框
        explanationSelectionText = ""  // 复制全文空
        explanationPanelSelectedText = ""  // 选区
        host.document.lastCommittedExplanationPanelSelectedText = ""  // 提交值
        clearExplanationTableState()
        host.errorMessage = nil  // 清错
        host.persistChatSession()  // 记住子栏
    }


    /// 讲解存成文件。
    func saveExplanationDocument() {
        host.selectRightPageTab(.readingAssistant)  // 朗读前切助手，按钮状态对得上
        host.assistant.selectReadingAssistantPanel(.explanation)  // 讲解栏
        host.persistChatSession()  // 记住子栏
        let content = explanationFileExportContent()  // 有对照表时用可 round-trip 的段式纯文本
        guard !content.isEmpty else {  // 没内容
            host.errorMessage = BookL10n.string("vm.error.noExplanationToSave")  // 提示
            return  // 不换文再读
        }
        host.document.exportContent(  // 另存
            content,
            panelTitle: BookL10n.string("vm.panel.saveExplanation"),
            panelMessage: BookL10n.string("vm.panel.saveExplanationMsg"),
            suggestedName: explanationFileName(),  // 文章名+讲解
            successPrefix: BookL10n.string("vm.saved.explanation"),
            onSaved: { [weak self] url in
                self?.saveExplanationAlignmentSidecar(near: url)  // 与 txt 同目录，打开时恢复对照表
            }
        )
    }


    /// 打开已存讲解。
    func openExplanationDocument() {
        guard !host.isRunning else { return }  // 跑着不删，避免历史被拆
        host.selectRightPageTab(.readingAssistant)  // 朗读前切助手，按钮状态对得上
        host.assistant.selectReadingAssistantPanel(.explanation)  // 讲解栏

        let panel = NSOpenPanel()  // 打开讲解文件
        panel.title = BookL10n.string("vm.panel.openExplanation")  // 讲解档
        panel.allowedContentTypes = [.plainText]  // 文本
        panel.allowsMultipleSelection = false  // 一次一条
        panel.canChooseDirectories = false  // 不要目录
        panel.directoryURL = DocumentExporter.lastDirectoryURL  // 上次

        guard panel.runModal() == .OK, let url = panel.url else { return }  // 取消
        loadExplanation(at: url)  // 拆消息
    }


    /// 读入讲解文本并拆成消息。
    func loadExplanation(at url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)  // utf8
                .trimmingCharacters(in: .whitespacesAndNewlines)  // 首尾空
            guard !text.isEmpty else {  // 空文件
                host.errorMessage = BookL10n.string("vm.error.explanationOpenEmpty")  // 空档
                return  // 不换文再读
            }
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()  // 记住
            clearExplanationTableState()
            applyImportedExplanationText(text)  // 按标记拆，失败整篇一条
            if !applyExplanationSidecarIfValid(from: url, content: text) {
                if alignExplanationWithSource(showFeedback: false),
                   var alignment = explanationAlignment {
                    alignment.provenance = .importedPlain
                    explanationAlignment = alignment
                }
            }
            host.errorMessage = nil  // 清错
            host.document.showTransientSaveMessage(BookL10n.format("vm.opened.explanation", url.lastPathComponent))  // 打开提示
        } catch {
            host.errorMessage = BookL10n.format("vm.error.openExplanation", error.localizedDescription)  // 读失败
        }
    }


    /// 讲解区全选。
    func selectAllExplanation() {
        host.selectRightPageTab(.readingAssistant)  // 朗读前切助手，按钮状态对得上
        host.assistant.selectReadingAssistantPanel(.explanation)  // 讲解栏
        let text = explanationTranscriptText()  // 可复制全文
        guard !text.isEmpty else {  // 空文件
            host.errorMessage = BookL10n.string("vm.error.noExplanationSelection")  // 空
            return  // 不换文再读
        }
        explanationSelectionText = text  // 给全选
        explanationSelectAllSignal = UUID()  // 视图全选
    }


    /// 朗读当前讲解有效文本。
    func readExplanationAloud() {
        readExplanationFullTextAloud()  // 工具栏「读讲解」走全文
    }


    /// 朗读左页全文。
    func readOriginalFullTextAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }  // 正在读就停

        let text = host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines)  // 左页
        guard !text.isEmpty else {  // 空文件
            host.errorMessage = BookL10n.string("vm.error.noSourceToSpeak")  // 没原文
            return  // 不换文再读
        }

        speakExplanation(text, source: .originalFull)  // 来源
    }


    /// 朗读左页选区。
    func readOriginalSelectionAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }  // 正在读就停

        let text = effectiveSelectedText  // 即时或提交
        guard !text.isEmpty else {  // 空文件
            host.errorMessage = BookL10n.string("vm.error.selectSourceToSpeak")  // 先选
            return  // 不换文再读
        }

        speakExplanation(text, source: .originalSelection)  // 来源
    }


    /// 朗读译文全文。
    func readTranslationFullTextAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }  // 正在读就停

        host.selectRightPageTab(.readingAssistant)  // 朗读前切助手，按钮状态对得上
        host.assistant.selectReadingAssistantPanel(.translation)

        let text = host.translation.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines)  // 译文全文
        guard !text.isEmpty else {  // 空文件
            host.errorMessage = BookL10n.string("vm.error.translationEmptySpeak")  // 没译文
            return  // 不换文再读
        }

        speakExplanation(text, source: .translationFull)  // 来源
    }


    /// 朗读译文选区。
    func readTranslationSelectionAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }  // 正在读就停

        host.selectRightPageTab(.readingAssistant)  // 朗读前切助手，按钮状态对得上
        host.assistant.selectReadingAssistantPanel(.translation)

        let text = effectiveLessonPlanSelectedText  // 译文选区
        guard !text.isEmpty else {  // 空文件
            host.errorMessage = BookL10n.string("vm.error.selectTranslationToSpeak")  // 先选
            return  // 不换文再读
        }

        speakExplanation(text, source: .translationSelection)  // 来源
    }


    /// 朗读讲解全文。
    func readExplanationFullTextAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }  // 正在读就停

        host.selectRightPageTab(.readingAssistant)  // 朗读前切助手，按钮状态对得上
        host.assistant.selectReadingAssistantPanel(.explanation)  // 讲解栏

        let text = explanationSpeakableText()  // 不要过程气泡
        guard !text.isEmpty else {  // 空文件
            host.errorMessage = BookL10n.string("vm.error.noExplanationToSpeak")  // 没讲解
            return  // 不换文再读
        }

        speakExplanation(text, source: .explanationFull)  // 来源
    }


    /// 朗读讲解选区。
    func readExplanationSelectionAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }  // 正在读就停

        host.selectRightPageTab(.readingAssistant)  // 朗读前切助手，按钮状态对得上
        host.assistant.selectReadingAssistantPanel(.explanation)  // 讲解栏
        syncExplanationSelectionText()  // 先刷全文再取选区

        let text = effectiveExplanationPanelSelectedText  // 讲解选区
        guard !text.isEmpty else {  // 空文件
            host.errorMessage = BookL10n.string("vm.error.selectExplanationToSpeak")  // 先选
            return  // 不换文再读
        }

        speakExplanation(text, source: .explanationSelection)  // 来源
    }


    @discardableResult
    /// 正在读就停，否则按当前来源读。
    private func toggleReadAloudIfSpeaking() -> Bool {
        if isSpeakingExplanation {  // 正在读
            host.assistant.stopExplanationSpeech()  // 当停止
            return true  // 调用方不要再开读
        }
        return false  // 普通助手句
    }


    /// 欢迎语不进 API 历史。
    func isReadingWelcomeMessage(_ message: ChatMessage) -> Bool {
        message.id == ReadingAssistantSession.defaultWelcomeMessage.id  // id 对上
            || (message.role == .assistant && message.content == ReadingAssistant.welcomeMessage)  // 语言变了 id 可能不同，比正文
    }


    /// 系统指令气泡，不当作用户句。
    private func isExplanationInstructionMessage(_ message: ChatMessage) -> Bool {
        guard message.role == .assistant else { return false }  // 用户句不是指令
        if isReadingWelcomeMessage(message) { return true }  // 欢迎当指令
        let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)  // 空也滤
        if content.isEmpty { return true }  // 空气泡
        if content.hasPrefix("已打开「"), content.contains("选择讲解") { return true }  // 打开文件引导
        return false  // 普通助手句
    }


    /// 保存讲解时的默认名。
    private func explanationFileName() -> String {
        let stem = (host.document.fileName as NSString).deletingPathExtension  // 去掉扩展
        let base = stem.isEmpty || stem == ReadingViewModel.untitledMarker ? BookL10n.string("file.articleStem") : stem  // 未命名用「文章」
        return "\(base)\(BookL10n.string("vm.filename.explanationSuffix"))"  // 加「讲解」
    }


    /// 选区变化写回，供朗读/追问。
    func syncExplanationSelectionText() {
        explanationSelectionText = explanationTranscriptText()  // 复制/全选用这份
    }


    /// 导入文本拆成对话。
    private func applyImportedExplanationText(_ text: String) {
        let parsed = parseImportedExplanationMessages(text)  // 按【用户|助手】拆
        readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage] + parsed  // 欢迎在前
        chatMessages = readingPromptMessages  // 上屏
        explanationSelectionText = explanationTranscriptText()  // 复制/全选用这份
        host.persistChatSession()  // 记住子栏
    }


    /// 按标记拆消息；失败整篇当一条。
    private func parseImportedExplanationMessages(_ text: String) -> [ChatMessage] {
        let marker = #"【(用户|助手)】"#  // 导出时写的标记
        guard let regex = try? NSRegularExpression(pattern: marker) else {  // 编译失败整篇一条
            return defaultImportedExplanationMessages(for: text)  // 用户草稿+整篇助手
        }

        let nsText = text as NSString  // UTF-16 range
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))  // 所有标记
        guard !matches.isEmpty else {  // 没有标记
            return defaultImportedExplanationMessages(for: text)  // 用户草稿+整篇助手
        }

        var messages: [ChatMessage] = []  // 按标记切
        for index in matches.indices {  // 每段到下一个标记
            let match = matches[index]  // 当前标记
            guard match.numberOfRanges > 1,  // 要有捕获组
                  let roleRange = Range(match.range(at: 1), in: text) else { continue }  // 角色字

            let roleLabel = String(text[roleRange])  // 用户或助手
            let role: ChatMessage.Role = roleLabel == "用户" ? .user : .assistant  // 其余当助手
            let contentStart = match.range.upperBound  // 标记后
            let contentEnd = index + 1 < matches.count ? matches[index + 1].range.lowerBound : nsText.length  // 下个标记或文末
            guard contentEnd > contentStart else { continue }  // 空段

            let raw = nsText.substring(with: NSRange(location: contentStart, length: contentEnd - contentStart))  // 含换行
            let content = raw.trimmingCharacters(in: .whitespacesAndNewlines)  // 去空白
            guard !content.isEmpty else { continue }  // 空段丢掉
            messages.append(ChatMessage(role: role, content: content))  // 一条
        }

        return messages.isEmpty ? defaultImportedExplanationMessages(for: text) : messages  // 全空则整篇
    }


    /// 导入失败时的占位。
    private func defaultImportedExplanationMessages(for text: String) -> [ChatMessage] {
        [
            ChatMessage(role: .user, content: BookL10n.string("vm.imported.explanationDraft")),  // 占位用户句
            ChatMessage(role: .assistant, content: text),  // 整篇当助手
        ]
    }

    /// 用左页选区出讲解。
    func explainSelection() {
        host.selectRightPageTab(.readingAssistant)  // 朗读前切助手，按钮状态对得上
        selectReadingAssistantPanel(.explanation)  // 切讲解

        let selection = effectiveSelectedText  // 即时或提交
        guard !selection.isEmpty else {  // 没选区
            host.errorMessage = BookL10n.string("vm.error.selectParagraph")  // 先选段
            return  // 不换文再读
        }

        if let configError = AppGuard.bookLLMErrorMessage(for: AppSettings.shared) {  // 没 Key
            host.errorMessage = configError  // 顶栏
            return  // 不换文再读
        }

        runSelectionParagraphExplanation()  // 选区按段 + 严格对照
    }


    /// 用左页全文出讲解。
    func explainFullText() {
        host.selectRightPageTab(.readingAssistant)  // 朗读前切助手，按钮状态对得上
        host.assistant.selectReadingAssistantPanel(.explanation)  // 讲解栏

        let fullText = host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines)  // 全文兜底
        guard !fullText.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.openArticleFirst")  // 先打开
            return  // 不换文再读
        }

        if let configError = AppGuard.bookLLMErrorMessage(for: AppSettings.shared) {  // 没 Key
            host.errorMessage = configError  // 顶栏
            return  // 不换文再读
        }

        runFullTextParagraphExplanation()  // 按段分批 + 严格对照
    }


    /// 朗读当前有效选区。
    func readSelectionAloud() {
        guard !toggleReadAloudIfSpeaking() else { return }  // 正在读就停

        host.selectRightPageTab(.readingAssistant)  // 朗读前切助手，按钮状态对得上

        let selected = effectiveSelectedText  // 选区
        let fullText = host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines)  // 全文兜底
        let text = selected.isEmpty ? fullText : selected  // 没选就读全文
        guard !text.isEmpty else {  // 空文件
            host.errorMessage = BookL10n.string("vm.error.noReadableContent")  // 都空
            return  // 不换文再读
        }

        let source: SpeechSource = selected.isEmpty ? .originalFull : .originalSelection  // 工具栏高亮
        speakExplanation(text, source: source)  // 开读
    }


    /// 朗读译文。
    func readLessonPlanAloud() {
        readTranslationFullTextAloud()  // 旧入口转到译文全文
    }


    /// 名著补充：把节选送给补全模型。
    func supplementClassicLiterature() {
        let trimmed = host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines)  // 要有原文
        guard !trimmed.isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.classicsPasteFirst")  // 先贴
            return  // 不换文再读
        }

        guard AppSettings.shared.isBookLLMConfigured else {  // 补全走读书 LLM
            host.errorMessage = BookL10n.string("vm.error.classicsNeedLLM")  // 没配
            return  // 不换文再读
        }

        let source = host.document.selectedText.isEmpty ? host.document.fileContent : host.document.selectedText  // 选区优先
        let replacingSelection = !host.document.selectedText.isEmpty  // 有选区只换选区

        host.beginRun(showsExecutionTrace: false)  // 补全不露轨迹
        host.errorMessage = nil  // 清错

        let prompt = ClassicLiteratureSupplement.buildPrompt(source: source, isSelection: replacingSelection)  // 节选/全文两套
        let llmMode = AIBookLLMPrompt.Mode.classicLiteratureSupplement  // 补全 system
        let settings = AppSettings.shared  // 语种和音色
        let selectionRange = replacingSelection ? host.document.currentSelectionRange(matching: source) : nil  // 写回用，对不上则整页

        host.activeTask?.cancel()  // 取消上一轮
        host.activeTask = Task {  // 流式预览
            do {
                var streamed = ""  // 本地拼，避免和讲解流串
                let reply = try await host.llmService.chat(  // 直接 LLM，不走编排器历史
                    prompt: prompt,
                    history: llmMode.apiHistory,
                    configuration: settings.bookLLMConfiguration,
                    systemPrompt: llmMode.systemPrompt,
                    maxTokens: 8192,
                    onEvent: { [weak self] event in
                        Task { @MainActor in
                            guard let self else { return }  // 释放
                            if case .textDelta(let delta) = event {  // 只收正文
                                streamed += delta  // 增量
                                self.host.streamingResponse = streamed  // 顶栏能看到在出
                                guard !replacingSelection else { return }  // 换选区时不直播到左页，避免闪
                                let preview = ClassicLiteratureSupplement.extractContent(from: streamed)  // 抽正文
                                    ?? ClassicLiteratureSupplement.stripMarkers(from: streamed)  // 抽不出就剥标记
                                if !preview.isEmpty {  // 空预览不覆盖
                                    self.host.document.fileContent = preview  // 整页直播
                                }
                            }
                        }
                    }
                )

                guard !Task.isCancelled else { return }  // 停止不写

                let finalText = ClassicLiteratureSupplement.extractContent(from: reply)  // 完整回复再抽一次
                    ?? ClassicLiteratureSupplement.stripMarkers(from: reply)  // 兜底
                host.document.applySupplementToLeftPage(finalText, selectionRange: selectionRange)  // 选区或整页
                host.document.persistLeftPage()  // 立刻存，防丢

                appendDisplayOnlyMessage(  // 失败也上一条
                    ChatMessage(  // 完成条数
                        role: .assistant,
                        content: BookL10n.format("vm.classics.done", finalText.count)
                    )
                )
            } catch {
                guard !Task.isCancelled else { return }  // 停止不写
                if !(error is CancellationError) {  // 取消不报
                    let message = LLMServiceErrorPresenter.message(for: error, provider: settings.bookProvider)  // 读书通道
                    host.errorMessage = message  // 顶栏
                    appendDisplayOnlyMessage(  // 失败也上一条
                        ChatMessage(role: .assistant, content: BookL10n.format("vm.classics.failed", message))  // 对话里留痕
                    )
                }
            }
            host.isLoading = false  // 收尾
            host.isRunning = false  // 按钮
            host.streamingToolStatus = ""  // 清
            host.resetStreamingState()  // 清流
        }
    }


    /// 拼讲解提示。选区优先于全文。
    private func buildChatPrompt(for question: String) -> String {
        let contextPercent = AppSettings.shared.bookContextPercent  // 本书设置
        var sections: [String] = []  // 节选+选区+问题

        if !host.document.fileContent.isEmpty {  // 有原文才节选
            let focus = host.document.selectedText.isEmpty ? nil : host.document.selectedText  // 围着选区截
            let excerpt = CursorContextCalculator.excerpt(  // 按百分比
                from: host.document.fileContent,  // 全文
                percent: contextPercent,  // 设置值
                focus: focus  // nil 则从文首
            )
            let anchorHint = focus != nil ? "，围绕选中内容" : ""  // 提示模型看选区
            sections.append("【当前阅读文本节选（\(Int(contextPercent))%\(anchorHint)）】\n\(excerpt)")  // 第一节
        }

        if !host.document.selectedText.isEmpty {  // 选区再单独给一份
            sections.append("【当前选中内容】\n\(host.document.selectedText)")  // 避免节选里被截掉
        }

        sections.append("【用户问题】\n\(question)")  // 最后
        return sections.joined(separator: "\n\n")  // 空行隔开
    }


    /// 选区前后文，按上下文百分比截。
    func surroundingContext(for selection: String, in content: String) -> String {
        let percent = AppSettings.shared.bookContextPercent  // 和提示同一套
        let radius = max(Int(Double(content.count) * percent / 100.0 / 2.0), 300)  // 前后各一半，至少 300 字
        guard let range = content.range(of: selection) else {  // 选区不在全文（已改过）
            return CursorContextCalculator.excerpt(from: content, percent: percent)  // 退回文首节选
        }

        let start = content.index(range.lowerBound, offsetBy: -radius, limitedBy: content.startIndex) ?? content.startIndex  // 向前夹到开头
        let end = content.index(range.upperBound, offsetBy: radius, limitedBy: content.endIndex) ?? content.endIndex  // 向后夹到文末
        return String(content[start ..< end])  // 含选区本身
    }


    /// 译文相关消息不进讲解历史。
    func isTranslationHistoryMessage(_ message: ChatMessage) -> Bool {
        BookL10nMarkers.isTranslationTaskMessage(message.content)  // 译文任务不当讲解历史
    }

    /// 只上屏，不进 API 历史。
    private func appendDisplayOnlyMessage(_ message: ChatMessage) {
        if host.isDisplaying(.reading) {  // 在助手页才追加
            chatMessages.append(message)  // 不写 readingPromptMessages
        }
    }


    /// 开朗读。source 记工具栏来源。
    func speakExplanation(_ text: String, source: SpeechSource, preferLowLatency: Bool = false) {
        let settings = AppSettings.shared  // 语种和音色
        let units = SpeechTextSanitizer.speechUnits(  // 按语种切句
            for: text,  // 原文
            mode: settings.speechLanguageMode  // 中/英/自动
        )
        guard !units.isEmpty else {  // 滤完没得读
            host.errorMessage = BookL10n.string("vm.error.speechEmpty")  // 提示
            return  // 不换文再读
        }

        ExplanationSpeechReader.shared.speak(text, preferLowLatency: preferLowLatency)  // 真正开声
        isSpeakingExplanation = true  // 按钮立刻切停止
        isExplanationSpeechPaused = false  // 不是暂停
        currentSpeechSource = source  // 工具栏高亮哪颗
        scheduleSpeakingStatusRefresh()  // 轮询合成器
    }


    /// 暂停/继续。
    func toggleExplanationSpeechPause() {
        let reader = ExplanationSpeechReader.shared  // 单例
        if reader.isPaused {  // 已暂停则继续
            reader.resume()  // 从断点
        } else if reader.isBusy {  // 在读则暂停
            reader.pause()  // 保持会话
        }
        syncExplanationSpeechState()  // 立刻刷按钮
    }


    /// 立刻停并清会话。
    func stopExplanationSpeech() {
        speakingRefreshTask?.cancel()  // 上一次轮询停
        ExplanationSpeechReader.shared.stop()  // 清会话
        isSpeakingExplanation = false  // 按钮恢复
        isExplanationSpeechPaused = false  // 不是暂停
        currentSpeechSource = nil  // 高亮灭
    }


    /// 合成器状态刷到按钮。
    func syncExplanationSpeechState() {
        let reader = ExplanationSpeechReader.shared  // 单例
        isExplanationSpeechPaused = reader.isPaused  // 暂停键
        isSpeakingExplanation = reader.isBusy  // 忙着就算在读
    }


    /// 延迟刷新，避开回调重入。
    private func scheduleSpeakingStatusRefresh() {
        speakingRefreshTask?.cancel()  // 上一次轮询停
        speakingRefreshTask = Task { @MainActor [weak self] in  // 200ms
            while !Task.isCancelled {  // 读完自己停
                guard let self else { return }  // 释放
                self.syncExplanationSpeechState()  // 刷
                guard ExplanationSpeechReader.shared.isBusy else { break }  // 读完退出
                try? await Task.sleep(nanoseconds: 200_000_000)  // 200ms
            }
        }
    }

}

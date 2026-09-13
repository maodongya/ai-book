import AIBookEvolution
import AppKit
import Combine
import Foundation

@MainActor
/// 翻译会话：译文内容、对齐、表格滚动与翻译 API 调用链。
final class ReadingTranslationSession: ObservableObject {
    unowned var host: ReadingViewModel!  // VM 注入


    @Published var lessonPlanSelectedText = ""  // 译文即时选区
    @Published var lessonPlanContent = "" {
        didSet {
            if !isApplyingAlignment {  // 程序写回不对 stale
                refreshTranslationAlignmentStaleState(fromManualEdit: true)  // 人手改了正文，渲染对不上就 stale
            }
            host.persistChatSession()  // 落盘
        }
    }
    @Published var translationAlignment: TranslationAlignment? {
        didSet {
            translationScrollSync.resetAnchors()  // 停止对滚
            if isApplyingAlignment { return }  // 批量写入时不同步、不落盘两次
            syncTranslationScrollPresentation()  // 刷对滚
            host.persistChatSession()  // 落盘
        }
    }
    @Published var translationTableViewEnabled = false {
        didSet {
            syncTranslationScrollPresentation()  // 刷对滚
            host.persistChatSession()  // 落盘
        }
    }
    @Published var translationTableScrollTargetID: UUID?  // 对照表滚到这一行
    @Published var translationTableHighlightedBlockID: UUID?  // 高亮行
    @Published var translationTableFocusTranslationBlockID: UUID?  // 拆行后焦点落到下一格
    @Published var showsTranslationProgressSheet = false  // 翻译专用弹出层
    @Published var translationStreamPreview = ""  // 仅弹出层展示，不进讲解/教案区
    @Published var translationProgressTitle = ""  // 弹出层标题（逐字/整段）
    let sourceTextScrollProxy = SelectableTextViewProxy()  // 左页滚动/高亮
    let translationTextScrollProxy = SelectableTextViewProxy()  // 右页纯文本滚动
    let translationScrollSync = TranslationScrollSync()  // 左右对滚
    var isApplyingAlignment = false  // 程序写 alignment/content 时抑制 didSet

    /// 有译文且未锁定才能跑本地对齐。
    var canAlignTranslationWithSource: Bool {
        !host.isRunning  // 请求中不对齐
            && translationAlignment?.isLocked != true  // 锁了不整体重排
            && !lessonPlanSourceText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 要有原文
            && !lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 要有译文
    }

    /// 锁定后禁止整体对齐和偏移。
    var isTranslationAlignmentLocked: Bool { translationAlignment?.isLocked == true }

    /// 对齐状态短文案，工具栏用。
    var translationAlignmentStatusText: String? {
        guard let alignment = translationAlignment else { return nil }  // 没对齐不显示状态
        if alignment.isStale { return BookL10n.string("vm.align.stale") }  // 过期优先
        var parts = [BookL10n.format("vm.align.anchored", alignment.anchoredBlockCount, alignment.blocks.count)]  // 钉住几段
        if alignment.isLocked { parts.append(BookL10n.string("vm.align.locked")) }  // 锁了加后缀
        if alignment.mode == .paragraph,
           !alignment.strictParagraphValidated,
           !alignment.isStale {
            parts.append(BookL10n.string("vm.align.nonStrictHeuristic"))
        }
        return parts.joined(separator: " · ")  // 状态条
    }

    /// 开关打开且当前对齐能画对照表。
    var showsTranslationTableView: Bool { translationTableViewEnabled && canUseTranslationTableView }

    /// 有对齐块才能用对照表。
    var canUseTranslationTableView: Bool {
        guard let alignment = translationAlignment, !alignment.isStale else { return false }  // 过期不进表
        switch alignment.mode {
        case .paragraph:  // 段数必须对上
            return alignment.blocks.contains { $0.level == .paragraph && $0.isAnchored }
        case .wordByWord:  // 宽松：坏 JSON 走纯文本
            return alignment.blocks.contains { $0.level == .word || $0.level == .phrase || $0.level == .summary }
        }
    }

    /// 整段 AI 验收通过且未 stale，表格启用严格 UI（原文只读、禁拆行）。
    var usesStrictParagraphTable: Bool {
        guard let alignment = translationAlignment else { return false }
        return alignment.mode == .paragraph
            && alignment.strictParagraphValidated
            && !alignment.isStale
    }

    /// 未过期、未锁定才跟滚。
    var shouldSyncTranslationScroll: Bool {
        host.mode.experienceMode == .learning  // 阅读模式不对滚
            && host.rightPageTab == .readingAssistant  // 在助手页
            && host.assistant.readingAssistantPanel == .translation  // 在译文栏
            && showsTranslationTableView  // 对照表开着
            && translationAlignment != nil  // 有对齐
            && translationAlignment?.isStale == false  // 没过期
    }



    /// 右页输入发送。空串直接回。
    func sendChatInput() {
        let text = host.assistant.readingChatInput.trimmingCharacters(in: .whitespacesAndNewlines)  // 右页输入当 refinement
        guard !text.isEmpty else { return }  // 空串不发

        if let configError = AppGuard.bookLLMErrorMessage(for: AppSettings.shared) {  // 没配 Key 先拦
            host.errorMessage = configError  // 顶栏
            return  // 原文没变，结束
        }

        host.assistant.readingChatInput = ""  // 先清空再请求，避免重发
        refineLessonPlan(instruction: text)  // 按 instruction 改已有译文
    }

    /// 译文全选。
    func selectAllRightPage() {
        host.document.selectAllRightPage()  // 转文档会话
    }


    /// 按当前原文出译文。
    func generateLessonPlan() {
        let source = lessonPlanSourceText()  // 选区优先
        guard !source.isEmpty else {  // 没原文
            host.errorMessage = BookL10n.string("vm.error.translationSourceFirst")  // 先选或打开
            return  // 原文没变，结束
        }
        host.selectRightPageTab(.readingAssistant)  // 切助手
        host.assistant.selectReadingAssistantPanel(.translation)  // 译文栏
        runLessonPlanTask(  // 流式请求
            displayText: BookL10n.string("vm.display.wordTranslation"),  // 气泡标题
            mode: .wordByWord,  // 逐词 JSON
            prompt: buildLessonPlanPrompt(
                source: source,
                existingPlan: nil,
                instruction: nil,
                mode: .wordByWord
            )
        )
    }


    /// 在已有译文上按 instruction 改。
    func refineLessonPlan(instruction: String? = nil) {
        let source = lessonPlanSourceText()  // 选区优先
        guard !source.isEmpty else {  // 没原文
            host.errorMessage = BookL10n.string("vm.error.translationSourceFirst")  // 先选或打开
            return  // 原文没变，结束
        }
        host.selectRightPageTab(.readingAssistant)  // 切助手
        host.assistant.selectReadingAssistantPanel(.translation)  // 译文栏
        let trimmedInstruction = instruction?.trimmingCharacters(in: .whitespacesAndNewlines)  // 空指令当没有
        runLessonPlanTask(  // 流式请求
            displayText: BookL10n.string("vm.display.paragraphTranslation"),  // 整段
            mode: .paragraph,  // 严格段对齐
            prompt: buildLessonPlanPrompt(
                source: source,
                existingPlan: existingTranslationForPrompt(),  // 已有译文让模型改
                instruction: trimmedInstruction?.isEmpty == false ? trimmedInstruction : nil,  // 空串不传
                mode: .paragraph
            )
        )
    }


    /// 清译文和对齐，不关文件。
    func clearLessonPlan() {
        guard !host.isRunning else { return }  // 跑着不清
        isApplyingAlignment = true  // 成对写，抑制 stale
        translationAlignment = nil  // 对齐丢掉
        lessonPlanContent = ""  // 正文清
        isApplyingAlignment = false  // 解开
    }


    /// 译文存盘。
    func saveLessonPlan() {
        let content = lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines)  // 没有块就用右页原文
        guard !content.isEmpty else {  // 提示
            host.errorMessage = BookL10n.string("vm.error.translationEmptySave")  // 顶栏
            return  // 原文没变，结束
        }
        host.document.exportContent(  // 另存面板
            content,
            panelTitle: BookL10n.string("vm.panel.saveTranslation"),
            panelMessage: BookL10n.string("vm.panel.saveTranslationMsg"),
            suggestedName: lessonPlanFileName(),
            successPrefix: BookL10n.string("vm.saved.translation")
        )
    }


    /// 另开一份译文文件。
    func openLessonPlanFile() {
        let panel = NSOpenPanel()
        panel.title = BookL10n.string("vm.panel.openTranslation")
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = DocumentExporter.lastDirectoryURL  // 上次目录

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadLessonPlan(at: url)  // 读入并对齐
    }


    /// 读入译文并尝试对齐。
    func loadLessonPlan(at url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)  // utf8
            isApplyingAlignment = true  // 成对写，抑制 stale
            lessonPlanContent = text  // 先上屏
            isApplyingAlignment = false  // 解开
            guard alignTranslationWithSource(showFeedback: false) else { return }  // 对齐失败就停，保留正文
            if var alignment = translationAlignment {  // 标来源
                alignment.provenance = .importedPlain  // 不是模型 JSON
                alignment.strictParagraphValidated = false  // 允许再修
                translationAlignment = alignment  // 成对写
            }
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()  // 记住
            host.errorMessage = nil  // 清旧错
            host.document.showTransientSaveMessage(BookL10n.format("vm.opened.translation", url.lastPathComponent))  // 打开提示
        } catch {
            host.errorMessage = BookL10n.format("vm.error.openTranslation", error.localizedDescription)  // 读失败
        }
    }


    /// 讲解/翻译共用的请求壳：取消旧任务、流式写回。
    private func runLessonPlanTask(
        displayText: String,
        mode: TranslationAlignmentMode,
        prompt: String
    ) {
        let settings = AppSettings.shared  // 本轮快照
        if let configError = AppGuard.bookLLMErrorMessage(for: settings) {  // fail-closed
            host.errorMessage = configError  // 顶栏
            return  // 原文没变，结束
        }

        host.assistant.readingAssistantActiveTask = .translation  // 顶栏「翻译中」
        host.beginRun(showsExecutionTrace: false)  // 翻译不露工具轨迹
        host.assistant.readingAssistantActiveTask = .translation  // beginRun 会清任务标，此处补回
        beginTranslationProgress(title: displayText)  // 弹出层展示流式过程
        host.errorMessage = nil  // 清旧错

        let llmMode = AIBookLLMPrompt.Mode.translation  // 翻译 system prompt
        host.activeTask?.cancel()  // 取消上一轮
        host.activeTask = Task {  // 主线程 Task
            defer { endTranslationProgress() }  // 成败都关弹出层
            do {
                let outcome = try await host.fetchAssistantReply(  // 走读书 LLM
                    prompt: prompt,
                    history: llmMode.apiHistory,
                    settings: settings,
                    llmMode: llmMode
                )

                guard !Task.isCancelled else { return }  // 停止不写
                let resolvedPlan = outcome.text.isEmpty ? translationStreamPreview : outcome.text  // 流在弹出层
                applyTranslationResult(resolvedPlan, title: displayText, mode: mode)  // 建对齐刷右页
            } catch {
                guard !Task.isCancelled else { return }  // 停止不写
                if !(error is CancellationError) {  // 取消不报错
                    let message = LLMServiceErrorPresenter.message(for: error, provider: AppSettings.shared.provider)  // 读书通道文案
                    host.errorMessage = message
                }
            }
            host.isLoading = false  // 收尾
            host.isRunning = false  // 按钮恢复
            host.activeTask = nil  // 允许下一轮
            host.resetStreamingState()  // 清流
        }
    }


    /// 打开翻译进度弹出层并清流式预览。
    func beginTranslationProgress(title: String) {
        translationProgressTitle = title
        translationStreamPreview = ""
        showsTranslationProgressSheet = true
    }


    /// 关闭翻译进度弹出层。
    func endTranslationProgress() {
        showsTranslationProgressSheet = false
        translationStreamPreview = ""
    }


    /// LLM 增量写入弹出层预览。
    func appendTranslationStreamPreview(_ delta: String) {
        guard !delta.isEmpty else { return }
        translationStreamPreview += delta
    }


    /// 模型回来后建对齐并刷新右页。
    private func applyTranslationResult(
        _ result: String,
        title: String,
        mode: TranslationAlignmentMode
    ) {
        let source = lessonPlanSourceText()  // 选区优先

        switch mode {  // 整段严格，逐词宽松
        case .paragraph:  // 段数必须对上
            switch TranslationAlignmentBuilder.buildStrictParagraph(from: result, source: source) {  // 失败不写半份
            case .success(var alignment):  // 校验过的
                let rendered = TranslationContentFormatter.renderIndexed(alignment, title: title)  // 带【标题】和编号
                alignment.blocks = rendered.blocks  // 带译文 range
                alignment.isStale = false  // 又能对滚
                isApplyingAlignment = true  // 成对写，抑制 stale
                translationAlignment = alignment  // 成对写
                lessonPlanContent = rendered.content  // 右页正文
                translationTableViewEnabled = true  // 整段默认真对照表
                isApplyingAlignment = false  // 解开
                syncTranslationScrollPresentation()  // 刷对滚
                host.persistChatSession()  // 落盘
            case .failure(let failure):  // 不改现有译文
                host.errorMessage = paragraphValidationErrorMessage(failure)  // 段数/空译/原文不符
            }
        case .wordByWord:  // 宽松：坏 JSON 走纯文本
            var alignment = TranslationAlignmentBuilder.build(from: result, source: source, mode: mode)  // 先 JSON 再纯文本
            alignment.provenance = .aiWordByWordJSON  // 来源
            alignment.strictParagraphValidated = false  // 允许再修
            let rendered = TranslationContentFormatter.renderIndexed(alignment, title: title)  // 带【标题】和编号
            alignment.blocks = rendered.blocks  // 带译文 range
            alignment.isStale = false  // 又能对滚
            isApplyingAlignment = true  // 成对写，抑制 stale
            translationAlignment = alignment  // 成对写
            lessonPlanContent = rendered.content  // 右页正文
            isApplyingAlignment = false  // 解开
            syncTranslationScrollPresentation()  // 刷对滚
            host.persistChatSession()  // 落盘
        }
    }


    /// 校验失败文案。下标给用户看时改成 1-based。
    private func paragraphValidationErrorMessage(_ failure: ParagraphAlignmentValidationFailure) -> String {
        switch failure {  // 每一种单独文案
        case .countMismatch(let expected, let actual):  // 模型段数不对
            return BookL10n.format("vm.error.paragraphAlign.countMismatch", expected, actual)  // 期望/实际
        case .indexCoverage:  // 下标不连续
            return BookL10n.string("vm.error.paragraphAlign.indexCoverage")  // 覆盖不全
        case .emptyTranslation(let index):  // 某段空译
            return BookL10n.format("vm.error.paragraphAlign.emptyTranslation", index + 1)  // 给用户看 1-based
        case .sourceTextMismatch(let index):  // 模型原文对不上
            return BookL10n.format("vm.error.paragraphAlign.sourceMismatch", index + 1)  // 第几段
        case .anchoringIncomplete(let expected, let actual):  // 没钉满
            return BookL10n.format("vm.error.paragraphAlign.anchoringIncomplete", actual, expected)  // 钉住/应钉
        }
    }


    @discardableResult
    /// 本地对齐。失败可弹反馈。
    func alignTranslationWithSource(showFeedback: Bool = true) -> Bool {
        if translationAlignment?.isLocked == true {  // 锁了拒绝整体重排
            if showFeedback {  // 手动点对齐才提示
                host.errorMessage = BookL10n.string("vm.error.alignLocked")  // 先解锁
            }
            return false  // 调用方停
        }

        let source = lessonPlanSourceText()  // 选区优先
        let content = lessonPlanContent  // 当前右页
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,  // 两边都要有
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {  // 缺一边
            if showFeedback {  // 手动点对齐才提示
                host.errorMessage = BookL10n.string("vm.error.alignNeedBoth")  // 提示
            }
            return false  // 调用方停
        }

        guard let outcome = TranslationAligner.align(source: source, translation: content) else {  // 启发式失败
            if showFeedback {  // 手动点对齐才提示
                host.errorMessage = BookL10n.string("vm.error.alignBuildFailed")  // 提示
            }
            return false  // 调用方停
        }

        translationScrollSync.resetAnchors()  // 停止对滚
        isApplyingAlignment = true  // 成对写，抑制 stale
        if let rendered = outcome.renderedContent {  // 切段后重排了译文
            lessonPlanContent = rendered  // 右页换成切好的
        }
        var alignment = outcome.alignment  // 本地启发式
        if alignment.mode == .paragraph {  // 本地重排不算严格校验
            alignment.strictParagraphValidated = false  // 允许再修
            alignment.provenance = .realignedHeuristic  // 来源
        }
        translationAlignment = alignment  // 成对写
        isApplyingAlignment = false  // 解开
        syncTranslationScrollPresentation()  // 刷对滚
        host.persistChatSession()  // 落盘
        host.errorMessage = nil  // 清旧错

        if showFeedback {  // 手动点对齐才提示
            let alignment = outcome.alignment  // 统计用
            let resegmented = outcome.renderedContent != nil ? BookL10n.string("vm.align.resegmentedSuffix") : ""  // 切过段加后缀
            host.document.showTransientSaveMessage(  // 钉住数
                BookL10n.format("vm.align.done", alignment.anchoredBlockCount, alignment.blocks.count, resegmented)
            )
        }
        return true  // 成功
    }


    /// 用户改了右页正文后重建对齐。
    func rebuildTranslationAlignment(from content: String) -> TranslationAlignment? {
        let source = lessonPlanSourceText()  // 选区优先
        guard !source.isEmpty else { return nil }  // 没原文建不成
        return TranslationAligner.align(source: source, translation: content)?.alignment  // 只要 alignment
    }


    /// 原文改了：能修则修对齐，不能就标 stale。
    func refreshTranslationAlignmentAfterSourceChange() {
        guard translationAlignment?.strictParagraphValidated != true else {  // 严格对齐不自动重排
            refreshTranslationAlignmentStaleState()  // 只标 stale
            return  // 原文没变，结束
        }
        if !lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {  // 有译文才修
            _ = alignTranslationWithSource(showFeedback: false)  // 静默
        }
    }


    /// 段被合成一块时按原文段再拆开。
    func repairCollapsedParagraphAlignmentIfNeeded() {
        guard translationAlignment?.strictParagraphValidated != true else { return }  // 严格的不拆
        _ = alignTranslationWithSource(showFeedback: false)  // 静默
    }


    /// 左页滚动，推给对齐同步。
    func handleSourceTextScroll(visibleRange: NSRange) {
        guard shouldSyncTranslationScroll,  // 对滚关着不管
              let alignment = alignmentForScrollSync() else { return }  // 过期或没有
        translationScrollSync.sourceDidScroll(visibleRange: visibleRange, alignment: alignment)  // 左推右
    }


    /// 右页纯文本滚动，对回原文。
    func handleTranslationTextScroll(visibleRange: NSRange) {
        guard shouldSyncTranslationScroll,  // 对滚关着不管
              !showsTranslationTableView,  // 对照表用另一套
              let alignment = alignmentForScrollSync() else { return }  // 过期或没有
        translationScrollSync.translationDidScroll(visibleRange: visibleRange, alignment: alignment)  // 右推左
    }


    /// 对照表可见行变化。
    func handleTranslationTableVisibleBlock(_ block: TranslationBlock) {
        guard canUseTranslationTableView,  // 表不可用
              let alignment = alignmentForScrollSync() else { return }  // 过期或没有
        translationTableHighlightedBlockID = block.id  // 先高亮
        let mappedBlock = alignment.blocks.first(where: { $0.id == block.id }) ?? block  // 用带 offset 的那份
        guard mappedBlock.isAnchored else { return }  // 没钉住不滚左页
        let sourceRange = mappedBlock.sourceRange  // 已加文件偏移
        DispatchQueue.main.async { [weak self] in  // 等表布局完
            guard let self else { return }  // 已释放
            if self.sourceTextScrollProxy.scrollToCharacterRange(sourceRange, anchor: .top) {  // 滚到段首
                self.sourceTextScrollProxy.highlightRange(sourceRange)  // 黄底
            }
        }
    }


    /// 锁对齐：禁止整体重排，单行仍可改。
    func lockTranslationAlignment() {
        guard var alignment = translationAlignment, !alignment.isStale else { return }  // 过期不能锁
        alignment.isLocked = true  // 禁止整体重排
        translationAlignment = alignment  // 成对写
        host.persistChatSession()  // 落盘
        host.document.showTransientSaveMessage(BookL10n.string("vm.align.savedLocked"))  // 已锁定
    }


    /// 解锁。原文变过会标 stale。
    func unlockTranslationAlignment() {
        guard var alignment = translationAlignment, alignment.isLocked else { return }  // 没锁不做事
        alignment.isLocked = false  // 解开
        translationAlignment = alignment  // 成对写
        host.persistChatSession()  // 落盘
        host.document.showTransientSaveMessage(BookL10n.string("vm.align.unlocked"))  // 已解锁
    }


    /// 改一块原文/译文/注。
    func updateTranslationTableBlock(
        id: UUID,
        sourceText: String? = nil,
        translationText: String? = nil,
        note: String? = nil
    ) {
        guard !host.isRunning, var alignment = translationAlignment, !alignment.isStale else { return }  // 请求中/过期不改
        guard let index = alignment.blocks.firstIndex(where: { $0.id == id }) else { return }  // 行没了
        if usesStrictParagraphTable, sourceText != nil { return }  // 严格表不准改原文列

        let source = lessonPlanSourceText()  // 选区优先
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }  // 没原文无法回钉

        isApplyingAlignment = true  // 成对写，抑制 stale
        defer { isApplyingAlignment = false }  // 出口都解开

        var blocks = alignment.blocks  // 本地改再写回
        var block = blocks[index]  // 这一行

        if let sourceText {  // 改了原文列
            let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)  // 空原文拒
            guard !trimmed.isEmpty else { return }  // 整次更新作废
            block.sourceText = trimmed  // 先改字
            if block.level != .summary {  // 摘要不钉原文
                let searchStart = sourceSearchStart(forBlockAt: index, in: blocks)  // 从上一段结束处找
                let range = TranslationAlignmentBuilder.reanchorSourceText(  // 先往后再从头
                    trimmed,
                    in: source,
                    searchStart: searchStart
                )
                block.sourceLocation = range.location  // UTF-16
                block.sourceLength = range.length  // 找不到就是 0
            }
        }

        if let translationText {  // 改了译列
            block.translationText = translationText.trimmingCharacters(in: .whitespacesAndNewlines)  // 去空白
        }

        if let note {  // 改了注
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)  // 空注当 nil
            block.note = trimmed.isEmpty ? nil : trimmed  // 不占格子
        }

        blocks[index] = block  // 写回数组
        alignment.blocks = blocks  // 还没渲染 range

        let rendered = TranslationContentFormatter.renderIndexed(alignment, title: translationDisplayTitle())  // 重排右页和 range
        alignment.blocks = rendered.blocks  // 带译文 range
        alignment.isStale = false  // 又能对滚
        translationAlignment = alignment  // 成对写
        lessonPlanContent = rendered.content  // 右页正文
        syncTranslationScrollPresentation()  // 刷对滚
        host.persistChatSession()  // 落盘
    }


    /// 一行拆两行。
    func splitTranslationTableBlock(
        id: UUID,
        translationBefore: String,
        translationAfter: String
    ) {
        guard !host.isRunning, var alignment = translationAlignment, !alignment.isStale else { return }  // 请求中/过期不改
        guard !usesStrictParagraphTable else { return }  // 严格表不拆行
        guard let index = alignment.blocks.firstIndex(where: { $0.id == id }) else { return }  // 行没了

        let block = alignment.blocks[index]  // 当前行
        guard block.level != .summary else { return }  // 摘要不拆

        let before = translationBefore.trimmingCharacters(in: .newlines)  // 回车前
        let after = translationAfter.trimmingCharacters(in: .newlines)  // 回车后
        guard !before.isEmpty || !after.isEmpty else { return }  // 两边都空不拆

        guard let nextIndex = nextTranslationTableEntryIndex(after: index, in: alignment.blocks) else {  // 没有下一行可合并
            host.document.showTransientSaveMessage(BookL10n.string("vm.align.cannotMergeDown"))  // 最后一行
            return  // 原文没变，结束
        }

        isApplyingAlignment = true  // 成对写，抑制 stale
        defer { isApplyingAlignment = false }  // 出口都解开

        var blocks = alignment.blocks  // 本地改再写回
        var current = blocks[index]  // 上半留本行
        current.translationText = before  // 回车前
        blocks[index] = current  // 写回

        var next = blocks[nextIndex]  // 下半并进下一行
        if after.isEmpty {  // 只删了换行
            next.translationText = next.translationText.trimmingCharacters(in: .newlines)  // 下一行去换行
        } else if next.translationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {  // 下一行原本空
            next.translationText = after  // 直接放
        } else {  // 拼到下一行前面
            next.translationText = after + next.translationText  // 不插空格，保持原样
        }
        blocks[nextIndex] = next  // 写回

        alignment.blocks = blocks  // 还没渲染 range
        let rendered = TranslationContentFormatter.renderIndexed(alignment, title: translationDisplayTitle())  // 重排右页和 range
        alignment.blocks = rendered.blocks  // 带译文 range
        alignment.isStale = false  // 又能对滚
        translationAlignment = alignment  // 成对写
        lessonPlanContent = rendered.content  // 右页正文
        translationTableFocusTranslationBlockID = next.id  // 焦点落到下一格
        syncTranslationScrollPresentation()  // 刷对滚
        host.persistChatSession()  // 落盘
    }


    /// 下一行可编辑下标。
    private func nextTranslationTableEntryIndex(after index: Int, in blocks: [TranslationBlock]) -> Int? {
        let current = blocks[index]  // 当前
        guard current.level != .summary else { return nil }  // 摘要没有「下一行」

        let entries = blocks  // 去掉摘要再按 order
            .enumerated()
            .filter { $0.element.level != .summary }  // 摘要不参与
            .sorted { $0.element.order < $1.element.order }  // 按阅读顺序

        guard let currentEntryIndex = entries.firstIndex(where: { $0.element.id == current.id }) else {  // 找不到
            return nil  // 避免模型照抄 JSON
        }
        let nextEntryIndex = entries.index(after: currentEntryIndex)  // 下一个可编辑
        guard nextEntryIndex < entries.endIndex else { return nil }  // 已经是最后
        return entries[nextEntryIndex].offset  // 原数组下标
    }


    /// 从哪一段原文开始翻，避免整篇重翻。
    private func sourceSearchStart(forBlockAt index: Int, in blocks: [TranslationBlock]) -> Int {
        let currentOrder = blocks[index].order  // 当前序号
        let previous = blocks  // 上一块已锚定的非摘要
            .filter { $0.level != .summary && $0.order < currentOrder && $0.isAnchored }  // 只看前面钉住的
            .sorted { $0.order < $1.order }  // 阅读顺序
            .last  // 最靠近的前一块
        guard let previous else { return 0 }  // 前面没有，从头搜
        return previous.sourceRange.location + previous.sourceRange.length  // 从它后面开始
    }


    /// 右页标题：有译文用文件名，否则「译文」。
    private func translationDisplayTitle() -> String? {
        let first = lessonPlanContent  // 看首行是不是【标题】
            .split(separator: "\n", omittingEmptySubsequences: false)  // 保留空行
            .first  // 首行
            .map(String.init)?  // 转 String
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""  // 去空白
        guard first.hasPrefix("【"), first.hasSuffix("】"), first.count > 2 else { return nil }  // 不成对就没有标题
        return String(first.dropFirst().dropLast())  // 去掉书名号
    }


    /// 对齐变了再推滚动同步。
    func syncTranslationScrollPresentation() {
        translationScrollSync.isEnabled = showsTranslationTableView  // 表开着才对滚
        translationScrollSync.usesTableView = showsTranslationTableView  // 表和纯文本两套
        translationScrollSync.onScrollTranslationToBlock = showsTranslationTableView  // 表：用 id 滚
            ? { [weak self] blockID in  // 弱引用
                self?.translationTableScrollTargetID = blockID  // 触发表滚动
                self?.translationTableHighlightedBlockID = blockID  // 同步高亮
            }
            : nil  // 纯文本不用这个回调
        if !showsTranslationTableView {  // 关表清目标
            translationTableScrollTargetID = nil  // 别留着下次误滚
            translationTableHighlightedBlockID = nil  // 高亮也清
        }
    }


    /// 给滚动同步用的对齐快照。
    private func alignmentForScrollSync() -> TranslationAlignment? {
        guard var alignment = translationAlignment, !alignment.isStale else { return nil }  // 过期不同步
        let offset = sourceRangeOffsetInFileContent()  // 选区相对全文的位移
        if offset != 0 {  // 对齐时用的是选区
            for index in alignment.blocks.indices where alignment.blocks[index].sourceLength > 0 {  // 只平移已锚定的
                alignment.blocks[index].sourceLocation += offset  // 换成文件坐标
            }
        }
        alignment.blocks = TranslationContentFormatter.indexTranslationRanges(  // 补译文 range 给右滚
            in: lessonPlanContent,  // 当前右页
            blocks: alignment.blocks,  // 已加 offset
            mode: alignment.mode  // 整段/逐词切法不同
        )
        return alignment  // 给 ScrollSync
    }


    /// 选区相对文件全文的偏移。
    private func sourceRangeOffsetInFileContent() -> Int {
        guard let hash = translationAlignment?.sourceContentHash else { return 0 }  // 没哈希当全文
        let fileNS = host.document.fileContent as NSString  // UTF-16

        /// 把范围平移一段。
        func offset(of source: String, preferring range: NSRange?) -> Int {
            let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)  // 空源位移 0
            guard !trimmed.isEmpty else { return 0 }  // 搜不到
            if let range,  // 有偏好 range 先在里面找
               range.location != NSNotFound,  // 有效
               range.length > 0,  // 非空
               NSMaxRange(range) <= fileNS.length {  // 没越界
                let slice = fileNS.substring(with: range) as NSString  // 偏好窗口
                let local = slice.range(of: trimmed)  // 窗口内偏移
                if local.location != NSNotFound {  // 窗口里找到
                    return range.location + local.location  // 换成全文坐标
                }
            }
            let found = fileNS.range(of: trimmed)  // 全文搜
            return found.location == NSNotFound ? 0 : found.location  // 找不到当 0
        }

        if TranslationSourceHasher.hash(host.document.selectedText) == hash {  // 对齐的是当前选区
            return offset(of: host.document.selectedText, preferring: host.document.selectedTextRange ?? host.document.lastCommittedSelectionRange)  // 用即时或提交 range
        }
        if TranslationSourceHasher.hash(host.document.lastCommittedSelectionText) == hash {  // 对齐的是上次提交选区
            return offset(of: host.document.lastCommittedSelectionText, preferring: host.document.lastCommittedSelectionRange)  // 提交 range
        }
        if TranslationSourceHasher.hash(host.document.fileContent) == hash {  // 对齐的是全文
            return offset(of: host.document.fileContent, preferring: nil)  // 从头，位移通常 0
        }
        return offset(of: lessonPlanSourceText(), preferring: host.document.lastCommittedSelectionRange)  // 兜底
    }


    /// 原文哈希变了标 stale。
    func refreshTranslationAlignmentStaleState(fromManualEdit: Bool = false) {
        guard var alignment = translationAlignment else { return }  // 没对齐

        if sourceHashMatches(alignment) {  // 原文还是同一份
            if alignment.isStale, !fromManualEdit {  // 原文回来了，取消 stale
                alignment.isStale = false  // 又能对滚
                translationAlignment = alignment  // 成对写
            } else if fromManualEdit,  // 人手改了右页
                      !TranslationContentFormatter.matchesRenderedContent(alignment, content: lessonPlanContent) {  // 和渲染结果不一致
                guard !alignment.isStale else { return }  // 已经标过
                alignment.isStale = true  // 原文换了
                translationAlignment = alignment  // 成对写
                translationScrollSync.resetAnchors()  // 停止对滚
            }
            return  // 原文没变，结束
        }

        guard !alignment.isStale else { return }  // 已经标过
        alignment.isStale = true  // 原文换了
        translationAlignment = alignment  // 成对写
        translationScrollSync.resetAnchors()  // 停止对滚
    }


    /// 当前原文和对齐时是否同一份。
    private func sourceHashMatches(_ alignment: TranslationAlignment) -> Bool {
        let candidates = [host.document.fileContent, host.document.selectedText, host.document.lastCommittedSelectionText]  // 三种可能的原文
        return candidates.contains { TranslationSourceHasher.hash($0) == alignment.sourceContentHash }  // 任一对上就算同一份
    }


    /// 出译文时用的原文。选区优先。
    private func lessonPlanSourceText() -> String {
        let selected = host.document.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)  // 即时选区
        if !selected.isEmpty { return selected }  // 有选区用选区
        return host.document.fileContent.trimmingCharacters(in: .whitespacesAndNewlines)  // 否则全文
    }


    /// 已有译文塞进提示，让模型改而不是重写。
    private func existingTranslationForPrompt() -> String? {
        if let alignment = translationAlignment, !alignment.blocks.isEmpty {  // 优先用块里的译
            let texts = alignment.blocks  // 去掉摘要
                .filter { $0.level != .summary }  // 摘要不是译文
                .sorted { $0.order < $1.order }  // 阅读顺序
                .map { $0.translationText.trimmingCharacters(in: .whitespacesAndNewlines) }  // 去空白
                .filter { !$0.isEmpty }  // 空段丢掉
            if !texts.isEmpty {  // 有货
                return texts.joined(separator: "\n\n")  // 空行拼，便于模型对段
            }
        }

        let content = lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines)  // 没有块就用右页原文
        guard !content.isEmpty else { return nil }  // 空则让模型新写
        if content.contains("\"translationText\"") || content.contains("```json") {  // JSON 不当已有译文
            return nil  // 避免模型照抄 JSON
        }
        return content  // 纯文本译文
    }


    /// 拼译文提示。
    private func buildLessonPlanPrompt(
        source: String,
        existingPlan: String?,
        instruction: String?,
        mode: TranslationAlignmentMode
    ) -> String {
        TranslationPromptBuilder.build(  // 拼提示
            source: source,
            existingPlan: existingPlan,
            instruction: instruction,
            mode: mode,
            targetLanguage: AppSettings.shared.resolvedTranslationTargetLanguage  // 本书设置的目标语
        )
    }


    /// 译文默认文件名。
    private func lessonPlanFileName() -> String {
        let stem = (host.document.fileName as NSString).deletingPathExtension  // 去掉扩展名
        let base = stem.isEmpty || stem == ReadingViewModel.untitledMarker ? BookL10n.string("file.articleStem") : stem  // 未命名用「文章」
        return "\(base)\(BookL10n.string("vm.filename.translationSuffix"))"  // 加「译文」后缀
    }

}

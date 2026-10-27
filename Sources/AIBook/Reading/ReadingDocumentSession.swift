import AIBookEvolution
import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
/// 左页文档会话：打开/保存、选区、目录浏览与 readme 笔记状态。
final class ReadingDocumentSession: ObservableObject {
    unowned var host: ReadingViewModel!  // VM init 注入


    @Published var fileContent = "" {
        didSet {
            isDirty = fileContent != savedContent  // 和上次落盘比，• 标靠这个
            scheduleAutoSaveIfNotes()  // 笔记档 2 秒后自动存
            if !host.isRestoringSession, !host.translation.isApplyingAlignment {  // 恢复/刷对齐时原文没真改
                host.translation.refreshTranslationAlignmentStaleState()  // 原文变了标 stale
            }
        }
    }
    @Published var fileName = ReadingViewModel.untitledMarker  // 未命名直到另存
    @Published private(set) var isDocumentOpen = false  // 空启动还没档
    @Published var selectedText = ""  // 左页当前选区，空则用 lastCommitted
    var lastCommittedSelectionText = ""  // 点空白后仍留给翻译/讲解
    var lastCommittedSelectionRange: NSRange?  // UTF-16，用来回钉
    @Published private(set) var leftSelectAllSignal = UUID()  // 变一次左页全选
    @Published private(set) var rightSelectAllSignal = UUID()  // 变一次译文全选
    var lastCommittedLessonPlanSelectedText = ""  // 译文选区提交值
    var lastCommittedExplanationPanelSelectedText = ""  // 讲解选区提交值
    @Published private(set) var isDirty = false  // 顶栏 •
    @Published var showDirectoryBrowser = false  // 目录浮层
    @Published var directoryBrowserSessions: [DirectoryBrowserRootSession] = []  // 多个授权根
    @Published var selectedDirectorySessionID: UUID?  // 当前根
    @Published private(set) var lastSaveMessage: String?  // 顶栏短暂提示
    var currentFileURL: URL?  // nil 表示笔记档
    /// 当前 .aibook 里已装入的各语言译文和讲解。
    @Published var bundledLanguages: [String: AIBookLanguagePayload] = [:]
    var bundledTranslationLanguageID: String?
    var bundledExplanationLanguageID: String?
    /// 讲解多语言切换。语言包仍放在本会话。
    lazy var explanationBundle = ReadingExplanationLanguages(document: self)
    private var savedContent = ""  // 上次成功写入的正文
    var selectedTextRange: NSRange?  // 和 selectedText 一起更新
    private var autoSaveTask: Task<Void, Never>?  // 笔记防抖
    private var saveMessageTask: Task<Void, Never>?  // 3 秒清提示
    private let readmeNotesStore = ReadmeNotesStore.shared  // 编号笔记存储

    /// 标题栏文件名；未打开文件时用未命名。
    var displayFileName: String {
        guard isDocumentOpen || currentFileURL != nil || !fileContent.isEmpty else {  // 什么都没开
            return BookL10n.string("vm.noFileOpen")  // 顶栏「未打开」
        }
        let name = currentFileURL?.lastPathComponent ?? fileName  // 有路径用文件名
        return isDirty ? "\(name) •" : name  // 脏了加点
    }

    /// 没打开文件就是在写笔记，保存走笔记路径。
    var isEditingNotes: Bool { currentFileURL == nil }



    /// 空文新档。未保存会先问。
    func newDocument() {
        guard !host.isRunning else { return }  // 跑着不改队列
        guard confirmDiscardUnsavedIfNeeded() else { return }  // 脏了先问

        host.assistant.stopExplanationSpeech()  // 换档停朗读
        fileContent = ""  // 空文
        savedContent = ""  // 和空文对齐，不当脏
        fileName = ReadingViewModel.untitledMarker  // 未命名
        currentFileURL = nil  // 笔记不绑用户文件
        isDocumentOpen = true  // 让顶栏有名字
        isDirty = false  // 干净
        host.mode.readingPageTexts = []  // 分页作废
        host.mode.readingSourcePageRanges = []  // 页 range 作废
        host.mode.readingSpreadIndex = 0  // 回到第一摊
        host.mode.experienceMode = .learning  // 新档用学习模式
        selectedText = ""  // 不再假装选区
        lastCommittedSelectionText = ""  // 提交值也清
        lastCommittedSelectionRange = nil  // 没有可回钉的
        selectedTextRange = nil  // 长度变了，旧 range 作废
        host.assistant.readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage]  // 讲解回欢迎
        host.syncDisplayedChatMessages()  // 气泡空
        host.assistant.readingChatInput = ""  // 输入框
        clearBundledLanguages()
        host.errorMessage = nil  // 清错
        host.persistChatSession()  // 落盘空档
    }


    /// 打开单个文本。
    func openFile() {
        guard confirmDiscardUnsavedIfNeeded() else { return }  // 脏了先问

        let panel = NSOpenPanel()  // 系统打开框
        panel.title = BookL10n.string("vm.panel.openTextFile")  // 只要文本
        var types: [UTType] = [.plainText]
        if let aibook = UTType(filenameExtension: "aibook") {
            types.append(aibook)
        }
        panel.allowedContentTypes = types  // txt 与 .aibook
        panel.allowsMultipleSelection = false  // 一次一个
        panel.canChooseDirectories = false  // 目录走另一入口

        guard panel.runModal() == .OK, let url = panel.url else { return }  // 取消就停
        openDocument(at: url)
    }


    /// 开目录浏览器。
    func openDirectory() {
        guard !host.isRunning else { return }  // 跑着不改队列
        if directoryBrowserSessions.isEmpty {  // 一个根都没有先挑
            guard let url = pickDirectoryURL() else { return }  // 取消不开浮层
            addDirectorySession(for: url)  // 已有根就切过去
        }
        showDirectoryBrowser = true  // 打开浮层
    }


    /// 再授权一个根。
    func addDirectoryFromPanel() {
        guard !host.isRunning else { return }  // 跑着不改队列
        guard let url = pickDirectoryURL() else { return }  // 取消不开浮层
        addDirectorySession(for: url)  // 已有根就切过去
        showDirectoryBrowser = true  // 打开浮层
    }


    /// 切换当前根。
    func selectDirectorySession(_ id: UUID) {
        selectedDirectorySessionID = id  // 只记当前，不落盘路径
    }


    /// 去掉一个根，书签一起删。
    func removeDirectorySession(_ id: UUID) {
        directoryBrowserSessions.removeAll { $0.id == id }  // 根和展开一起丢
        if selectedDirectorySessionID == id {  // 删的是当前根
            selectedDirectorySessionID = directoryBrowserSessions.first?.id  // 恢复上次第一个
        }
        persistDirectoryBrowserSessions()  // 书签立刻写
    }


    /// 展开状态立刻落盘。
    func toggleDirectoryNodeExpanded(sessionID: UUID, path: String) {
        guard let index = directoryBrowserSessions.firstIndex(where: { $0.id == sessionID }) else { return }  // 可能已被删
        if directoryBrowserSessions[index].expandedPaths.contains(path) {  // 已展开则收
            directoryBrowserSessions[index].expandedPaths.remove(path)  // 收起
        } else {  // 没选区整页替换
            directoryBrowserSessions[index].expandedPaths.insert(path)  // 展开
        }
        persistDirectoryBrowserSessions()  // 书签立刻写
    }


    /// 关目录，不卸 session。
    func dismissDirectoryBrowser() {
        showDirectoryBrowser = false  // session 留下，下次还在
    }


    /// 按 target 落到原文/译文/讲解。
    func openFileFromDirectory(at url: URL, target: DirectoryFileOpenTarget) {
        switch target {  // 同一文件三种打开方式
        case .original:  // 当左页
            guard confirmDiscardUnsavedIfNeeded() else { return }  // 脏了先问
            openDocument(at: url)  // txt 或 .aibook
        case .translation:  // 当译文
            host.selectRightPageTab(.readingAssistant)  // 先切到译文
            host.assistant.selectReadingAssistantPanel(.translation)  // 否则全选信号没人收
            host.translation.loadLessonPlan(at: url)  // 读入并对齐
        case .explanation:  // 当讲解
            guard !host.isRunning else { return }  // 跑着不改队列
            host.selectRightPageTab(.readingAssistant)  // 先切到译文
            host.assistant.selectReadingAssistantPanel(.explanation)  // 讲解栏
            host.assistant.loadExplanation(at: url)  // 拆成对话
        }
        DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()  // 下次面板
    }


    /// 系统选目录。取消回 nil。
    private func pickDirectoryURL() -> URL? {
        let panel = NSOpenPanel()  // 系统打开框
        panel.title = BookL10n.string("vm.panel.chooseFolder")  // 只要文件夹
        panel.canChooseFiles = false  // 文件不算根
        panel.canChooseDirectories = true  // 选目录
        panel.allowsMultipleSelection = false  // 一次一个
        panel.directoryURL = DocumentExporter.lastDirectoryURL  // 记住上次
        guard panel.runModal() == .OK, let url = panel.url else { return nil }  // 取消 nil
        DocumentExporter.lastDirectoryURL = url  // 这个根本身记下
        return url  // 调用方去建 session
    }


    /// 授权成功后扫树。
    private func addDirectorySession(for url: URL) {
        let standardized = url.standardizedFileURL  // 去 .. 和重复斜杠，便于比
        if let existing = directoryBrowserSessions.first(where: { $0.rootURL == standardized }) {  // 同一根不建两份
            selectedDirectorySessionID = existing.id  // 切过去
            if existing.tree == nil, !existing.isLoading {  // 上次扫失败才再扫
                loadDirectoryTree(for: existing.id)  // 后台扫
            }
            return  // 不追加
        }

        let session = DirectoryBrowserRootSession.new(url: standardized)  // 新 id、空树
        directoryBrowserSessions.append(session)  // 先上屏再扫
        selectedDirectorySessionID = session.id  // 立刻选中
        persistDirectoryBrowserSessions()  // 书签立刻写
        loadDirectoryTree(for: session.id)  // 并行 Task
    }


    /// 启动时从书签恢复仍在的根。
    func restoreDirectoryBrowserSessions() {
        let stored = DirectoryBrowserPersistence.load()  // 书签；权限没了也先建
        directoryBrowserSessions = stored.map { storedRoot in  // 树稍后扫
            let url = URL(fileURLWithPath: storedRoot.urlPath, isDirectory: true).standardizedFileURL  // 当目录
            return DirectoryBrowserRootSession(  // tree 空，isLoading 后面再开
                id: storedRoot.id,
                rootURL: url,
                tree: nil,
                isLoading: false,
                expandedPaths: Set(storedRoot.expandedPaths),
                loadError: nil
            )
        }
        selectedDirectorySessionID = directoryBrowserSessions.first?.id  // 恢复上次第一个
        for session in directoryBrowserSessions {  // 每个根扫一遍
            loadDirectoryTree(for: session.id)  // 并行 Task
        }
    }


    /// 根和展开状态落盘。
    private func persistDirectoryBrowserSessions() {
        DirectoryBrowserPersistence.save(directoryBrowserSessions)  // id、路径、展开
    }


    /// 扫一个根。失败写 loadError。
    private func loadDirectoryTree(for sessionID: UUID) {
        guard let index = directoryBrowserSessions.firstIndex(where: { $0.id == sessionID }) else { return }  // 可能已被删
        let rootURL = directoryBrowserSessions[index].rootURL  // 扫之前抓出来，避免下标过期
        directoryBrowserSessions[index].isLoading = true  // 转圈
        directoryBrowserSessions[index].loadError = nil  // 清上次错

        Task.detached(priority: .userInitiated) {  // 别堵主线程
            let tree = DirectoryTreeScanner.scan(root: rootURL)  // 失败 nil
            await MainActor.run { [weak self] in // 等待异步完成
                guard let self,  // VM 已释放就丢结果
                      let currentIndex = self.directoryBrowserSessions.firstIndex(where: { $0.id == sessionID }) else {  // 扫完根可能没了
                    return  // 不追加
                }
                self.directoryBrowserSessions[currentIndex].isLoading = false  // 转圈停
                if let tree {  // 扫到了
                    self.directoryBrowserSessions[currentIndex].tree = tree  // 整棵替换
                    self.directoryBrowserSessions[currentIndex].loadError = nil  // 成功清错
                    if self.directoryBrowserSessions[currentIndex].expandedPaths.isEmpty {  // 首次默认展开根
                        self.directoryBrowserSessions[currentIndex].expandedPaths.insert(tree.id)  // 根节点 id
                    }
                } else {  // 没选区整页替换
                    self.directoryBrowserSessions[currentIndex].tree = nil  // 空树
                    self.directoryBrowserSessions[currentIndex].loadError = BookL10n.string("vm.error.readDirectory")  // 红字
                }
                self.persistDirectoryBrowserSessions()  // 展开状态可能刚补了根
            }
        }
    }


    /// 拖入的文件按原文打开。
    func openDroppedFile(at url: URL) {
        let ext = url.pathExtension.lowercased()
        guard ext == "txt" || ext == "aibook" || ext.isEmpty else {  // 纯文本或 AIBook 包
            host.errorMessage = BookL10n.string("vm.error.txtOnly")
            return
        }
        guard confirmDiscardUnsavedIfNeeded() else { return }  // 脏了先问
        openDocument(at: url)
    }


    @discardableResult
    /// 有未保存改动先问。取消则中止。
    func confirmDiscardUnsavedIfNeeded() -> Bool {
        guard isDirty else { return true }  // 没改过不用问
        return AppGuard.confirmDiscardUnsavedChanges()  // 取消则调用方中止
    }


    /// 读文本进左页并重置分页。
    func loadFile(at url: URL, resetChat: Bool = true) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)  // 按 utf8，坏编码抛
            fileContent = text  // 左页
            savedContent = text  // 刚读的，不脏
            isDirty = false  // 干净
            fileName = url.lastPathComponent  // 顶栏
            currentFileURL = url  // 路径可能是第一次 saveAs 定的
            isDocumentOpen = true  // 让顶栏有名字
            selectedText = ""  // 不再假装选区
            lastCommittedSelectionText = ""  // 提交值也清
            lastCommittedSelectionRange = nil  // 没有可回钉的
            selectedTextRange = nil  // 长度变了，旧 range 作废
            if resetChat {  // 恢复会话时 false
                host.assistant.readingPromptMessages = []  // 讲解清空，欢迎由 persist 那边补
                host.evolution.evolutionPromptMessages = []  // 进化也清
                host.syncDisplayedChatMessages()  // 气泡空
            }
            clearBundledLanguages()
            host.errorMessage = nil  // 清错
            host.persistChatSession()  // 落盘空档
            host.translation.refreshTranslationAlignmentAfterSourceChange()  // 能修对齐就修
            host.assistant.refreshExplanationAlignmentStaleState()
        } catch {
            host.errorMessage = BookL10n.format("vm.error.readFile", error.localizedDescription)  // 读失败
        }
    }


    /// 保存。`.aibook` 回写整包，其它文件只写原文。
    func save() {
        if let url = currentFileURL, url.pathExtension.lowercased() == "aibook" {
            writeAIBook(to: url)
            return
        }
        if let url = currentFileURL {  // 已绑文件也回写磁盘
            writeContent(to: url)  // 有路径写文件
            syncReadmeNotesIfNeeded()  // 笔记档还要回写 store
        } else {  // 没选区整页替换
            saveReadmeNotes()  // 没路径当笔记
        }
    }


    /// 另存左页。
    func saveAs() {
        host.document.exportContent(  // 另存面板
            fileContent,  // 整页
            panelTitle: BookL10n.string("vm.panel.saveAsText"),
            panelMessage: BookL10n.string("vm.panel.saveAsTextMsg"),
            suggestedName: DocumentExporter.suggestedFileName(
                currentFileURL: currentFileURL,
                fileName: fileName
            ),
            successPrefix: BookL10n.string("vm.saved.as")
        )
    }


    /// 只存当前选区。
    func saveSelectionAs() {
        let selection = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)  // 空选区不导出
        guard !selection.isEmpty else {  // 提示先选
            host.errorMessage = BookL10n.string("vm.error.selectExportText")  // 顶栏
            return  // 不追加
        }

        host.document.exportContent(  // 另存面板
            selection,  // 只写选区
            panelTitle: BookL10n.string("vm.panel.exportSelection"),
            panelMessage: BookL10n.string("vm.panel.exportSelectionMsg"),
            suggestedName: DocumentExporter.suggestedFileName(
                currentFileURL: currentFileURL,
                fileName: fileName,
                selectionSuffix: true
            ),
            successPrefix: BookL10n.string("vm.saved.exportSelection")
        )
    }


    /// 按格式导出。
    func exportContent(
        _ content: String,
        panelTitle: String,
        panelMessage: String,
        suggestedName: String,
        successPrefix: String,
        onSaved: ((URL) -> Void)? = nil
    ) {
        guard !content.isEmpty else { return }  // 没笔记就保持未打开

        let directory = DocumentExporter.defaultDirectory(currentFileURL: currentFileURL)  // 同目录优先
        guard let destination = DocumentExporter.runSavePanel(  // 取消 nil
            title: panelTitle,
            message: panelMessage,
            suggestedName: suggestedName,
            directory: directory
        ) else { return }

        if FileManager.default.fileExists(atPath: destination.path),  // 覆盖先问
           !AppGuard.confirmOverwriteExistingFile(at: destination) {  // 取消则停
            return  // 不追加
        }

        do {
            try DocumentExporter.write(content, to: destination) // 调用可能失败的方法
            if content == fileContent {  // 另存的是整页才切路径
                currentFileURL = destination  // 下次保存走新路径
                fileName = destination.lastPathComponent  // 顶栏
                savedContent = fileContent  // 干净
                isDirty = false  // 干净
            }
            host.errorMessage = nil  // 清错
            host.document.showTransientSaveMessage("\(successPrefix) \(destination.lastPathComponent)")  // 3 秒提示
            onSaved?(destination)  // 译文可写 sidecar
        } catch {
            host.errorMessage = BookL10n.format("vm.error.saveFile", error.localizedDescription)  // 写失败
        }
    }


    /// 编号笔记和左页互相跟。
    func syncLeftPageWithEvolutionCommands(from url: URL, formatted: String) {
        fileContent = formatted  // 编号命令上左页
        savedContent = formatted  // 和队列一致
        fileName = url.lastPathComponent  // 顶栏
        currentFileURL = url  // 路径可能是第一次 saveAs 定的
        isDocumentOpen = true  // 让顶栏有名字
        isDirty = false  // 干净
        do {
            try ReadmeNotesStore.shared.save(formatted) // 调用可能失败的方法
        } catch {
            host.errorMessage = BookL10n.format("vm.error.syncCommandNotes", error.localizedDescription)  // store 失败不影响内存
        }
    }

    /// 将优化队列格式化为左页编号命令（N、…）并同步展示与持久化。

    func syncLeftPageFromOptimizationQueue() {
        guard !host.evolution.optimizationQueue.items.isEmpty else { return }  // 空队列不覆盖左页
        let formatted = NumberedNoteFormatter.format(host.evolution.optimizationQueue)  // N、正文
        fileContent = formatted  // 编号命令上左页
        savedContent = formatted  // 和队列一致
        isDirty = false  // 干净
        if !isDocumentOpen {  // 笔记还没标打开
            isDocumentOpen = true  // 让顶栏有名字
        }
        do {
            try ReadmeNotesStore.shared.save(formatted) // 调用可能失败的方法
        } catch {
            host.errorMessage = BookL10n.format("vm.error.syncCommandNotes", error.localizedDescription)  // store 失败不影响内存
        }
        if let url = currentFileURL {  // 已绑文件也回写磁盘
            try? DocumentExporter.write(formatted, to: url)  // 失败只靠 store 报错
        }
    }

    /// 左页含编号命令行时回写优化队列，使手动编辑与进化队列保持一致。

    func syncOptimizationQueueFromLeftPageIfNeeded() {
        guard !host.isRunning else { return }  // 跑着不改队列
        guard !host.evolution.optimizationQueue.items.contains(where: { $0.status == .running }) else { return }  // 有 running 不覆盖
        let imported = OptimizationQueue.importFromNotes(fileContent)  // 解析编号行
        guard !imported.items.isEmpty else { return }  // 不像笔记就不动队列
        host.evolution.optimizationQueue = imported  // 整表替换
        host.evolution.persistOptimizationQueue()  // 队列落盘
    }


    /// 导入队列会覆盖时先问。
    func confirmReplaceOptimizationQueue() -> Bool {
        let alert = NSAlert()  // 覆盖确认
        alert.messageText = BookL10n.string("vm.alert.replaceQueueTitle")  // 标题
        alert.informativeText = BookL10n.format("vm.alert.replaceQueueMsg", host.evolution.optimizationQueue.items.count)  // 带条数
        alert.alertStyle = .warning  // 警告
        alert.addButton(withTitle: BookL10n.string("action.replace"))  // 默认按钮
        alert.addButton(withTitle: BookL10n.string("alert.cancel"))  // 取消
        return alert.runModal() == .alertFirstButtonReturn  // 点替换才 true
    }


    /// 助手输出默认文件名。
    func assistantOutputFileName(for message: ChatMessage) -> String {
        let formatter = DateFormatter()  // 文件名用本地时区
        formatter.dateFormat = "yyyyMMdd-HHmm"  // 到分钟，避免撞名
        return "AI查询内容-\(formatter.string(from: message.timestamp)).txt"  // 按消息时间
    }


    /// 顶栏短暂「已保存」。
    func showTransientSaveMessage(_ message: String) {
        lastSaveMessage = message  // 立刻上屏
        saveMessageTask?.cancel()  // 上一条 3 秒计时作废
        saveMessageTask = Task { @MainActor [weak self] in  // 弱引用
            try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3 秒
            guard !Task.isCancelled else { return }  // 被新提示打断
            self?.lastSaveMessage = nil  // 顶栏清掉
        }
    }


    /// 读编号笔记。
    func loadReadmeNotes() {
        let content = ReadmeNotesStore.shared.loadInitialContent()  // 空则不改左页
        guard !content.isEmpty else { return }  // 没笔记就保持未打开

        fileContent = content
        savedContent = content
        fileName = "readme-notes.txt"  // 约定名，自动存靠它认
        currentFileURL = nil  // 笔记不绑用户文件
        isDocumentOpen = true  // 让顶栏有名字
        isDirty = false  // 干净
    }


    /// 写编号笔记。
    private func saveReadmeNotes() {
        do {
            try ReadmeNotesStore.shared.save(fileContent) // 调用可能失败的方法
            savedContent = fileContent  // 干净
            fileName = "readme-notes.txt"  // 约定名，自动存靠它认
            currentFileURL = nil  // 笔记不绑用户文件
            isDirty = false  // 干净
            host.errorMessage = nil  // 清错
            syncOptimizationQueueFromLeftPageIfNeeded()  // 编号行回写队列
        } catch {
            host.errorMessage = BookL10n.format("vm.error.saveCommandNotes", error.localizedDescription)  // 笔记存失败
        }
    }


    /// 队列变了才回写笔记。
    private func syncReadmeNotesIfNeeded() {
        guard fileName == "readme-notes.txt" || currentFileURL == nil else { return }  // 普通文件不碰 store
        do {
            try ReadmeNotesStore.shared.save(fileContent) // 调用可能失败的方法
        } catch {
            host.errorMessage = BookL10n.format("vm.error.syncCommandNotes", error.localizedDescription)  // store 失败不影响内存
        }
    }


    /// 原子写文件。失败抛给调用方。
    private func writeContent(to url: URL) {
        do {
            try DocumentExporter.write(fileContent, to: url) // 调用可能失败的方法
            currentFileURL = url  // 路径可能是第一次 saveAs 定的
            fileName = url.lastPathComponent  // 顶栏
            savedContent = fileContent  // 干净
            isDirty = false  // 干净
            host.errorMessage = nil  // 清错
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()  // 下次面板
            host.document.showTransientSaveMessage(BookL10n.format("vm.saved.file", url.lastPathComponent))  // 已保存
        } catch {
            host.errorMessage = BookL10n.format("vm.error.saveFile", error.localizedDescription)  // 写失败
        }
    }


    /// 左页选区。空则用 lastCommitted。
    func updateSelection(_ text: String, range: NSRange? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)  // 空白不当选区
        if !trimmed.isEmpty {  // 有字才提交
            selectedText = trimmed  // 补全结果变成选区
            selectedTextRange = range  // 给翻译回钉
            lastCommittedSelectionText = trimmed  // 点空白后还在
            lastCommittedSelectionRange = range  // range 一起提交
        } else {  // 没选区整页替换
            selectedText = ""  // 不再假装选区
            selectedTextRange = nil  // 长度变了，旧 range 作废
        }
    }


    /// 译文选区。
    func updateLessonPlanSelection(_ text: String, range: NSRange? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)  // 空白不当选区
        if !trimmed.isEmpty {  // 有字才提交
            host.translation.lessonPlanSelectedText = trimmed  // 译文即时选区
            lastCommittedLessonPlanSelectedText = trimmed  // 提交
        } else {  // 没选区整页替换
            host.translation.lessonPlanSelectedText = ""  // 即时清，提交值保留
        }
    }


    /// 讲解区选区。空则清 lastCommitted。
    func updateExplanationPanelSelection(_ text: String, range: NSRange? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)  // 空白不当选区
        if !trimmed.isEmpty {  // 有字才提交
            host.assistant.explanationPanelSelectedText = trimmed  // 讲解即时
            lastCommittedExplanationPanelSelectedText = trimmed  // 提交
        } else {  // 没选区整页替换
            host.assistant.explanationPanelSelectedText = ""  // 即时清
        }
    }

    /// 左页全选。
    func selectAllLeftPage() {
        guard !fileContent.isEmpty else {  // 空页不能全选
            host.errorMessage = BookL10n.string("vm.error.noSelectableText")  // 提示
            return  // 不追加
        }
        leftSelectAllSignal = UUID()  // 视图观察这个
    }


    /// 译文全选。
    func selectAllRightPage() {
        host.selectRightPageTab(.readingAssistant)  // 先切到译文
        host.assistant.selectReadingAssistantPanel(.translation)  // 否则全选信号没人收
        guard !host.translation.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {  // 没译文
            host.errorMessage = BookL10n.string("vm.error.translationEmptySelectAll")  // 提示
            return  // 不追加
        }
        rightSelectAllSignal = UUID()  // 译文视图全选
    }

    /// 名著补全结果写回左页。
    func applySupplementToLeftPage(_ supplemented: String, selectionRange: Range<String.Index>?) {
        let trimmed = supplemented.trimmingCharacters(in: .whitespacesAndNewlines)  // 空补全不改页
        guard !trimmed.isEmpty else { return }  // 模型空回复

        if let range = selectionRange, isValidRange(range, in: fileContent) {  // 有有效选区就替换选区
            fileContent.replaceSubrange(range, with: trimmed)  // 其余原文保留
            selectedText = trimmed  // 补全结果变成选区
            selectedTextRange = nil  // 长度变了，旧 range 作废
        } else {  // 没选区整页替换
            fileContent = trimmed  // 整页
            selectedText = ""  // 不再假装选区
            selectedTextRange = nil  // 长度变了，旧 range 作废
        }
    }


    /// 当前选区 UTF-16。
    func currentSelectionRange(matching source: String) -> Range<String.Index>? {
        if let selectedTextRange,  // 优先用即时 range
           let range = Range(selectedTextRange, in: fileContent),  // UTF-16 转 String.Index
           String(fileContent[range]) == source {  // 对得上才用，防错位
            return range  // 给补全写回
        }

        let matches = ranges(of: source, in: fileContent)  // 没有可靠 range 就搜
        return matches.count == 1 ? matches[0] : nil  // 多处同文不敢猜
    }


    /// 把选区拆成不重叠段。
    private func ranges(of needle: String, in haystack: String) -> [Range<String.Index>] {
        guard !needle.isEmpty else { return [] }  // 空针不搜
        var ranges: [Range<String.Index>] = []  // 所有不重叠命中
        var searchRange = haystack.startIndex..<haystack.endIndex  // 从头
        while let range = haystack.range(of: needle, range: searchRange) {  // 一段一段往后
            ranges.append(range)  // 记下
            searchRange = range.upperBound..<haystack.endIndex  // 从这次结束处继续
        }
        return ranges  // 可能空
    }


    /// location/length 都在全文内。
    private func isValidRange(_ range: Range<String.Index>, in text: String) -> Bool {
        range.lowerBound >= text.startIndex && range.upperBound <= text.endIndex  // 含边界
    }


    /// txt 当原文，`.aibook` 同时恢复各语言译文和讲解。
    func openDocument(at url: URL) {
        if url.pathExtension.lowercased() == "aibook" {
            openAIBook(at: url)
        } else {
            loadFile(at: url)
        }
    }

    /// 另存为 `.aibook`。已打开的包里其它语言会保留。
    func saveAsAIBook() {
        guard !host.isRunning else { return }
        guard !fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            host.errorMessage = BookL10n.string("vm.error.aibookEmpty")
            return
        }
        let directory = DocumentExporter.defaultDirectory(currentFileURL: currentFileURL)
        guard let destination = runAIBookSavePanel(
            suggestedName: aibookSuggestedName(),
            directory: directory
        ) else { return }
        writeAIBook(to: destination)
    }

    /// 把当前右页译文记到指定语言，供多语言队列和 .aibook 保存。
    func captureDisplayedTranslation(languageID: String) {
        guard AIBookBundle.isLanguageID(languageID) else { return }
        bundledTranslationLanguageID = languageID
        snapshotActiveBundledLanguages()
    }

    /// 右页正在显示的译文语言。
    var displayedTranslationLanguage: TranslationTargetLanguage {
        if let id = bundledTranslationLanguageID,
           let language = TranslationTargetLanguage(rawValue: id),
           language != .followAppLanguage {
            return language
        }
        return AppSettings.shared.resolvedTranslationTargetLanguage
    }

    /// 已经有译文、可以在右页切换的语言。
    var translationLanguagesAvailableToShow: [TranslationTargetLanguage] {
        TranslationTargetLanguage.selectableTargets.filter { language in
            bundledLanguages[language.rawValue]?.hasTranslation == true
        }
    }

    /// 右页已有译文但还没进语言包时，记到当前显示语言下。
    func adoptDisplayedTranslationIfNeeded() {
        let text = host.translation.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let id = displayedTranslationLanguage.rawValue
        guard AIBookBundle.isLanguageID(id) else { return }
        if bundledLanguages[id]?.hasTranslation == true { return }
        captureDisplayedTranslation(languageID: id)
    }

    /// 切换右页显示的译文。先写回当前语言，再装入所选语言。
    func showTranslationLanguage(_ language: TranslationTargetLanguage) {
        guard AIBookBundle.isLanguageID(language.rawValue) else { return }
        let current = displayedTranslationLanguage
        if current != language {
            captureDisplayedTranslation(languageID: current.rawValue)
        }
        guard let payload = bundledLanguages[language.rawValue], payload.hasTranslation else { return }
        bundledTranslationLanguageID = language.rawValue
        host.translation.installBundledTranslation(
            text: payload.translationText ?? "",
            alignment: payload.translationAlignment
        )
        if AppSettings.shared.translationTargetLanguage != language {
            AppSettings.shared.translationTargetLanguage = language
        }
    }

    /// 菜单点一种语言：有译文就显示，否则切换是否参加下次翻译。
    func handleTranslationLanguageMenuClick(_ language: TranslationTargetLanguage) {
        let settings = AppSettings.shared
        let selected = settings.translationTargetLanguages.contains(language)
        let hasTranslation = bundledLanguages[language.rawValue]?.hasTranslation == true
        switch BundledLanguageSelection.effect(alreadySelected: selected, hasContent: hasTranslation) {
        case .show:
            showTranslationLanguage(language) // 有译文就切右页，不取消勾选
        case .toggle(let thenShow):
            settings.toggleTranslationTargetLanguage(language) // 没译文才改勾选
            if thenShow, settings.translationTargetLanguages.contains(language) {
                showTranslationLanguage(language) // 刚勾上且包里已有译文
            }
        }
    }

    /// 目标语言或界面语言变化时，换上包里对应的译文和讲解。
    func activateBundledLanguagesForCurrentSettings() {
        guard !bundledLanguages.isEmpty else { return }
        snapshotActiveBundledLanguages()
        let translationID = AppSettings.shared.resolvedTranslationTargetLanguage.rawValue
        if let payload = bundledLanguages[translationID], payload.hasTranslation {
            bundledTranslationLanguageID = translationID
            host.translation.installBundledTranslation(
                text: payload.translationText ?? "",
                alignment: payload.translationAlignment
            )
        }
        let explanationID = AppSettings.shared.resolvedExplanationTargetLanguage.rawValue // 讲解不跟界面语言走
        if let payload = bundledLanguages[explanationID], payload.hasExplanation {
            bundledExplanationLanguageID = explanationID
            host.assistant.installBundledExplanation(
                text: payload.explanationText ?? "",
                alignment: payload.explanationAlignment
            )
        }
    }

    private func openAIBook(at url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let bundle = try AIBookBundle.decode(data)
            host.assistant.stopExplanationSpeech()
            bundledLanguages = bundle.languages
            currentFileURL = url
            fileName = url.lastPathComponent
            fileContent = bundle.source
            savedContent = bundle.source
            isDirty = false
            isDocumentOpen = true
            selectedText = ""
            lastCommittedSelectionText = ""
            lastCommittedSelectionRange = nil
            selectedTextRange = nil
            host.assistant.readingPromptMessages = [ReadingAssistantSession.defaultWelcomeMessage]
            host.evolution.evolutionPromptMessages = [ReadingEvolutionSession.defaultEvolutionWelcomeMessage]
            host.syncDisplayedChatMessages()
            host.assistant.readingChatInput = ""
            applyBundledLanguage(bundle, kind: .translation)
            applyBundledLanguage(bundle, kind: .explanation)
            host.errorMessage = nil
            host.persistChatSession()
            showTransientSaveMessage(BookL10n.format("vm.opened.aibook", url.lastPathComponent))
        } catch {
            host.errorMessage = BookL10n.format("vm.error.aibookRead", error.localizedDescription)
        }
    }

    private enum BundledPart {
        case translation
        case explanation
    }

    private func applyBundledLanguage(_ bundle: AIBookBundle, kind: BundledPart) {
        switch kind {
        case .translation:
            let preferred = AppSettings.shared.resolvedTranslationTargetLanguage.rawValue
            let id = bundle.languages[preferred]?.hasTranslation == true
                ? preferred
                : bundle.languages.keys.sorted().first { bundle.languages[$0]?.hasTranslation == true }
            if let id, let payload = bundle.languages[id] {
                bundledTranslationLanguageID = id
                host.translation.installBundledTranslation(
                    text: payload.translationText ?? "",
                    alignment: payload.translationAlignment
                )
            } else {
                bundledTranslationLanguageID = nil
                host.translation.installBundledTranslation(text: "", alignment: nil)
            }
        case .explanation:
            let preferred = AppSettings.shared.resolvedExplanationTargetLanguage.rawValue // 打开后先看记住的讲解语言
            let id = bundle.languages[preferred]?.hasExplanation == true
                ? preferred
                : bundle.languages.keys.sorted().first { bundle.languages[$0]?.hasExplanation == true }
            if let id, let payload = bundle.languages[id] {
                bundledExplanationLanguageID = id
                host.assistant.installBundledExplanation(
                    text: payload.explanationText ?? "",
                    alignment: payload.explanationAlignment
                )
            } else {
                bundledExplanationLanguageID = nil
                host.assistant.installBundledExplanation(text: "", alignment: nil)
            }
        }
    }

    private func writeAIBook(to url: URL) {
        snapshotActiveBundledLanguages()
        let stem = (url.deletingPathExtension().lastPathComponent as NSString).deletingPathExtension
        let title = stem.isEmpty ? BookL10n.string("file.articleStem") : url.deletingPathExtension().lastPathComponent
        let bundle = AIBookBundle(title: title, source: fileContent, languages: bundledLanguages)
        do {
            let data = try bundle.encoded()
            try data.write(to: url, options: .atomic)
            currentFileURL = url
            fileName = url.lastPathComponent
            savedContent = fileContent
            isDirty = false
            host.errorMessage = nil
            DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()
            showTransientSaveMessage(BookL10n.format("vm.saved.aibook", url.lastPathComponent))
            host.persistChatSession()
        } catch {
            host.errorMessage = BookL10n.format("vm.error.aibookSave", error.localizedDescription)
        }
    }

    /// 把当前右页写回正在显示的语言，其它语言不动。
    func snapshotActiveBundledLanguages() { // 讲解切换也要写回当前语言
        let translationID = bundledTranslationLanguageID
            ?? AppSettings.shared.resolvedTranslationTargetLanguage.rawValue
        if AIBookBundle.isLanguageID(translationID) {
            let text = host.translation.lessonPlanContent
            var payload = bundledLanguages[translationID] ?? AIBookLanguagePayload()
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if bundledTranslationLanguageID == translationID {
                    payload.translationText = nil
                    payload.translationAlignment = nil
                }
            } else {
                payload.translationText = text
                payload.translationAlignment = bundledAlignment(
                    host.translation.translationAlignment,
                    content: text
                )
                bundledTranslationLanguageID = translationID
            }
            storePayload(payload, languageID: translationID)
        }

        let explanationID = bundledExplanationLanguageID
            ?? AppSettings.shared.resolvedExplanationTargetLanguage.rawValue // 没记住时用讲解设置
        if AIBookBundle.isLanguageID(explanationID) {
            let text = host.assistant.bundledExplanationExportText()
            var payload = bundledLanguages[explanationID] ?? AIBookLanguagePayload()
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if bundledExplanationLanguageID == explanationID {
                    payload.explanationText = nil
                    payload.explanationAlignment = nil
                }
            } else {
                payload.explanationText = text
                payload.explanationAlignment = bundledAlignment(
                    host.assistant.explanationAlignment,
                    content: text
                )
                bundledExplanationLanguageID = explanationID
            }
            storePayload(payload, languageID: explanationID)
        }
    }

    private func bundledAlignment(_ alignment: TranslationAlignment?, content: String) -> TranslationAlignment? {
        guard let alignment, !alignment.isStale else { return nil }
        guard TranslationSourceHasher.hash(fileContent) == alignment.sourceContentHash else { return nil }
        guard TranslationContentFormatter.matchesRenderedContent(alignment, content: content) else { return nil }
        return alignment
    }

    private func storePayload(_ payload: AIBookLanguagePayload, languageID: String) {
        if payload.hasTranslation || payload.hasExplanation {
            bundledLanguages[languageID] = payload
        } else {
            bundledLanguages.removeValue(forKey: languageID)
        }
    }

    private func clearBundledLanguages() {
        bundledLanguages = [:]
        bundledTranslationLanguageID = nil
        bundledExplanationLanguageID = nil
    }

    private func aibookSuggestedName() -> String {
        let stem = ((currentFileURL?.deletingPathExtension().lastPathComponent) ?? fileName)
        let base = (stem as NSString).deletingPathExtension
        let name = base.isEmpty || base == ReadingViewModel.untitledMarker
            ? BookL10n.string("file.articleStem")
            : base
        return "\(name).aibook"
    }

    private func runAIBookSavePanel(suggestedName: String, directory: URL) -> URL? {
        let panel = NSSavePanel()
        panel.title = BookL10n.string("vm.panel.saveAIBook")
        panel.message = BookL10n.string("vm.panel.saveAIBookMsg")
        if let type = UTType(filenameExtension: "aibook") {
            panel.allowedContentTypes = [type]
        }
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName
        panel.directoryURL = directory
        guard panel.runModal() == .OK, var url = panel.url else { return nil }
        if url.pathExtension.lowercased() != "aibook" {
            url = url.appendingPathExtension("aibook")
        }
        DocumentExporter.lastDirectoryURL = url.deletingLastPathComponent()
        return url
    }

    /// 左页按当前文件路径存。
    func persistLeftPage() {
        if let url = currentFileURL, url.pathExtension.lowercased() == "aibook" {
            writeAIBook(to: url)
            return
        }
        if let url = currentFileURL {  // 已绑文件也回写磁盘
            writeContent(to: url)  // 有路径写文件
        } else {  // 没选区整页替换
            saveReadmeNotes()  // 没路径当笔记
        }
    }


    /// 笔记档延迟自动存。
    private func scheduleAutoSaveIfNotes() {
        guard isEditingNotes, isDirty, !host.isRestoringSession else { return }  // 普通文件不自动存

        autoSaveTask?.cancel()  // 输入中防抖
        autoSaveTask = Task { @MainActor [weak self] in  // 2 秒后
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 秒
            guard !Task.isCancelled else { return }  // 被新提示打断
            self?.saveReadmeNotes()  // 写 store
        }
    }

}

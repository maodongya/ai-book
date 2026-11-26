import SwiftUI
import UniformTypeIdentifiers

/// iOS 根界面。窄屏一次一页；够宽时原文和助手并排，中间只有分隔线。
struct IOSRootView: View {
    @StateObject private var shell = IOSShellModel()
    @StateObject private var document = IOSDocument()
    @StateObject private var localization = IOSLocalizationSettings()
    @ObservedObject private var styleManager = BookStyleManager.shared // 单例，与 Mac 共用偏好
    @StateObject private var settings = IOSModelSettings()
    @StateObject private var service = IOSReadingService()
    @StateObject private var speaker = IOSSpeaker()
    @StateObject private var voice = IOSVoiceController()
    @State private var exportPresented = false
    @State private var folderItems: [URL] = []
    @State private var folderPresented = false
    @State private var keptFolder: URL?
    @State private var libraryFiles: [URL] = []
    @State private var browseAfterLibrary = false
    @State private var showManual = false
    @State private var showPrivacy = false

    var body: some View {
        GeometryReader { geo in
            let split = IOSLayout.usesSideBySide(width: geo.size.width) && shell.page.sitsBesideSource
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    IOSPaper.page.ignoresSafeArea()
                    content(split: split) // 正文铺满，顶栏用 safeAreaInset 让位
                }
                if shell.showsBubble {
                    IOSBottomTabBar(shell: shell, document: document)
                }
            }
        }
        .background {
            IOSFilePicker(kind: $document.importKind) { url, kind in
                openImported(url, kind: kind) // 选中后写回对应的页
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                if speaker.speaking {
                    speechBar // 朗读播控在最上
                }
                if shell.page != .reading {
                    IOSTopCommandBar(
                        shell: shell,
                        document: document,
                        settings: settings,
                        service: service,
                        speaker: speaker,
                        voice: voice,
                        showManual: $showManual,
                        showPrivacy: $showPrivacy
                    )
                }
            }
        }
        .iosBookAppearance(localization: localization, styleManager: styleManager) // 语言与纸色跟 Mac 令牌
        .onAppear {
            service.speaker = speaker
            voice.bind(shell: shell, document: document, settings: settings, service: service, speaker: speaker)
            document.modelReady = settings.isReady // 已保存的密钥打开时就能讲解
            openBundledBooksIfNeeded() // 安装包里的书拷进文稿，并打开默认的一本
            #if DEBUG
            applySnapshotTranslationFixtureIfNeeded()
            #endif
        }
        .onChange(of: settings.apiKey) { _, _ in document.modelReady = settings.isReady }
        .onChange(of: settings.baseURL) { _, _ in document.modelReady = settings.isReady }
        .onChange(of: settings.model) { _, _ in document.modelReady = settings.isReady }
        .onReceive(NotificationCenter.default.publisher(for: .iosShortcutEnterReading)) { _ in
            guard document.hasSource else { return }
            shell.enterReading()
        }
        .onReceive(NotificationCenter.default.publisher(for: .iosShortcutStop)) { _ in
            service.cancel()
            speaker.stop()
        }
        .fileExporter(
            isPresented: $exportPresented,
            document: IOSDataFile(data: document.exportData()),
            contentType: document.exportKind == .aibook ? .data : .plainText,
            defaultFilename: document.exportFilename()
        ) { result in
            if case .success = result, document.exportKind?.clearsSourceDirty == true {
                document.dirty = false // 原文已经交给系统文件
            }
            document.exportKind = nil
        }
        .onChange(of: document.exportKind) { _, kind in
            exportPresented = kind != nil // 菜单和口令都从这里导出
        }
        .onOpenURL { url in
            openImported(url, kind: .book)
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            openImported(url, kind: importKind(for: url))
            return true
        }
        .sheet(isPresented: $folderPresented, onDismiss: releaseFolder) {
            NavigationStack {
                List(folderItems, id: \.path) { url in
                    Button(url.lastPathComponent) {
                        openImported(url, kind: .book) // 目录里点一份 txt 或 aibook
                        folderPresented = false
                    }
                }
                .navigationTitle(BookL10n.string("directory.opened"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(BookL10n.string("alert.cancel")) {
                            folderPresented = false // 空目录也能返回
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $document.libraryPresented, onDismiss: openBrowserIfAsked) {
            librarySheet // 应用文稿里的文本，取消一定能关掉
        }
        .sheet(isPresented: $showManual) {
            NavigationStack {
                IOSUserManualView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(BookL10n.string("action.close")) { showManual = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPrivacy) {
            NavigationStack {
                IOSPrivacyPolicyView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(BookL10n.string("action.close")) { showPrivacy = false }
                        }
                    }
            }
        }
    }

    /// 本应用的文稿目录。种子书和用户打开的文件都放这里。
    private var documentsFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] // 沙盒文稿，重装会清空
    }

    /// 安装后把包内的书放进文稿。还没打开正文时，直接打开默认的那一本。
    private func openBundledBooksIfNeeded() {
        let documents = documentsFolder
        if let seed = IOSSeedLibrary.bundledRoot(),
           let book = try? IOSSeedLibrary.install(from: seed, into: documents) {
            if !document.hasSource {
                openImported(book, kind: .book) // 冷启动直接看到初始书，方便测试
            }
            return // 有种子书就不再塞静夜思
        }
        placeSampleTextIfNeeded() // 包里没有 book 文件夹时仍留一份短文
    }

    /// 模拟器的「我的 iPhone」是空的。包里没有种子书时放一份短文。
    private func placeSampleTextIfNeeded() {
        let file = documentsFolder.appendingPathComponent("静夜思.txt")
        guard !FileManager.default.fileExists(atPath: file.path) else { return }
        try? "床前明月光，疑是地上霜。".write(to: file, atomically: true, encoding: .utf8) // 只在还没有文件时写一份
    }

    /// 应用文稿目录里的文件夹、txt 和 aibook。
    private func refreshLibrary() {
        let folder = documentsFolder
        if let seed = IOSSeedLibrary.bundledRoot() {
            _ = try? IOSSeedLibrary.install(from: seed, into: folder) // 后补进包里的书也能在列表里出现
        } else {
            placeSampleTextIfNeeded()
        }
        libraryFiles = IOSSeedLibrary.libraryEntries(in: folder) // 文件夹在前，散落的书在后
    }

    /// 列表关掉之后再弹系统选择器，避免两个页面叠在一起。
    private func openBrowserIfAsked() {
        guard browseAfterLibrary else { return }
        browseAfterLibrary = false
        document.importKind = .book // 此时列表已经不在
    }

    /// 打开文件先走这份列表。系统选择器仍可从右上角进去。
    private var librarySheet: some View {
        NavigationStack {
            List(libraryFiles, id: \.path) { url in
                if IOSSeedLibrary.isDirectory(url) {
                    NavigationLink(url.lastPathComponent) {
                        seedFolderPage(url) // 点文件夹再看里面的书
                    }
                } else {
                    Button(url.lastPathComponent) {
                        openImported(url, kind: .book) // 点文件名就读进原文
                        document.libraryPresented = false
                    }
                }
            }
            .navigationTitle(BookL10n.string("welcome.openTextFile"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(BookL10n.string("alert.cancel")) {
                        document.libraryPresented = false // 返回原文，不再停在空的系统浏览器
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(BookL10n.string("action.openFile")) {
                        browseAfterLibrary = true // 等这份列表关掉
                        document.libraryPresented = false
                    }
                }
            }
            .onAppear { refreshLibrary() } // 每次打开都重新列一遍
        }
    }

    /// 一个种子文件夹里的书。点名字就打开，并关掉文稿列表。
    private func seedFolderPage(_ folder: URL) -> some View {
        let files = IOSSeedLibrary.bookFiles(under: folder) // 这一类下面的 txt 和 aibook
        return List(files, id: \.path) { url in // 只列这一文件夹里的书
            Button(url.lastPathComponent) {
                openImported(url, kind: .book) // 和顶层文件同一条打开路径
                document.libraryPresented = false // 打开后回到原文
            }
        }
        .navigationTitle(folder.lastPathComponent) // 标题用文件夹名，例如「中庸」
    }

    /// 单页或并排。并排时点讲解或翻译只换右半。
    @ViewBuilder
    private func content(split: Bool) -> some View {
        if shell.page == .reading {
            IOSReadingPage(document: document, shell: shell, voice: voice)
        } else if split {
            HStack(spacing: 0) {
                sourcePage(showsPageMenu: false) // 底栏负责换页
                Rectangle()
                    .fill(IOSPaper.inkMuted.opacity(0.35))
                    .frame(width: 1) // 分隔线，不画书脊
                IOSSplitAssistantPane(shell: shell) {
                    translationPage(showsPageMenu: false)
                } explanation: {
                    explanationPage(showsPageMenu: false)
                }
            }
        } else {
            single // 窄于并排宽度，立刻回到单页
        }
    }

    /// iPhone 和窄 iPad 的整屏。
    @ViewBuilder
    private var single: some View {
        switch shell.page {
        case .source:
            sourcePage() // 整屏原文，左侧带换页菜单
        case .translation:
            translationPage() // 整屏翻译，左侧带换页菜单
        case .explanation:
            explanationPage() // 整屏讲解，左侧带换页菜单
        case .settings:
            IOSSettingsPage(settings: settings, shell: shell, localization: localization, styleManager: styleManager)
        case .reading:
            IOSReadingPage(document: document, shell: shell, voice: voice)
        }
    }

    private func sourcePage(showsPageMenu: Bool = true) -> some View {
        IOSSourcePage(document: document, shell: shell, settings: settings, service: service, speaker: speaker, showsPageMenu: showsPageMenu) // 原文页可隐藏左侧菜单
    }

    private func explanationPage(showsPageMenu: Bool = true) -> some View {
        IOSExplanationPage(document: document, shell: shell, settings: settings, service: service, speaker: speaker, showsPageMenu: showsPageMenu) // 讲解页同样
    }

    private func translationPage(showsPageMenu: Bool = true) -> some View {
        IOSTranslationPage(document: document, shell: shell, settings: settings, service: service, speaker: speaker, showsPageMenu: showsPageMenu) // 翻译页同样
    }

    private func importKind(for url: URL) -> IOSImportKind {
        let ext = url.pathExtension.lowercased()
        if ext == "aibook" || ext == "txt" { return .book }
        return .book
    }

    /// 打开文本、aibook、目录，或把一份文本写进讲解、译文。
    private func openImported(_ url: URL, kind: IOSImportKind) {
        let accessed = url.startAccessingSecurityScopedResource()
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if exists, isDirectory.boolValue, kind == .directory {
            IOSDirectoryBookmark.save(url)
            keptFolder?.stopAccessingSecurityScopedResource()
            keptFolder = accessed ? url : nil // 列表还在时不能还掉目录权限
            let children = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
            folderItems = children.filter { ["txt", "aibook"].contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            folderPresented = true
            return
        }
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        if kind == .book,
           url.pathExtension.lowercased() == "aibook",
           let data = try? Data(contentsOf: url),
           let bundle = try? AIBookBundle.decode(data) {
            document.openBundle(bundle) // 原文和各语言稿一起回来
            shell.select(.source)
            return
        }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        switch kind {
        case .explanation:
            document.storeExplanation(text) // 只写当前语言的讲解
            shell.select(.explanation)
        case .translation:
            document.storeTranslation(text)
            shell.select(.translation)
        case .book:
            document.openText(name: url.deletingPathExtension().lastPathComponent, text: text)
            shell.select(.source)
        case .directory:
            break // 文件夹已在上面列出来
        }
    }

    #if DEBUG
    /// 注入示例译文并切到翻译页，供模拟器对照截图。
    private func applySnapshotTranslationFixtureIfNeeded() {
        guard IOSSnapshotHints.translationCompare else { return }
        document.openText(
            name: "静夜思",
            text: "床前明月光，\n疑是地上霜。\n\n举头望明月，\n低头思故乡。"
        )
        document.storeTranslation(
            "Before my bed a pool of light,\nIs it hoar-frost on the ground?\n\nHead up, I watch the moon; head down,\nIn thought of home I am drowned."
        )
        shell.select(.translation)
    }
    #endif

    /// 目录列表关掉后再归还安全范围。
    private func releaseFolder() {
        keptFolder?.stopAccessingSecurityScopedResource()
        keptFolder = nil
    }

    /// 正在朗读时独占顶栏一行：左侧来源，右侧播控。
    private var speechBar: some View {
        HStack(spacing: 10) {
            if let key = speaker.contextTitleKey {
                Text(BookL10n.string(key))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(IOSPaper.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(speaker.paused ? BookL10n.string("action.resume") : BookL10n.string("action.pause")) {
                if speaker.paused {
                    speaker.resume() // 从暂停处继续
                } else {
                    speaker.pause() // 先停住，不丢掉进度
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(IOSPaper.ink)
            Button(BookL10n.string("action.stop")) { speaker.stop() } // 结束这一次朗读
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .iosPanelChrome(edge: .bottom)
    }
}

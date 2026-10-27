import SwiftUI

/// 应用入口：一扇阅读窗 + 菜单命令。状态在 ReadingViewModel / AppSettings，这里只接线。
@main
struct AIBookApp: App {
    /// AppKit 代理，用来在退出前问未保存。
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    /// 整窗共享的阅读会话，生命周期跟 Scene 走。
    @StateObject private var viewModel = ReadingViewModel()
    /// 风格令牌，跟单例走以免多窗各画一套。
    @ObservedObject private var styleManager = BookStyleManager.shared
    /// 界面语言和模型设置。
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            AIBookRootView(viewModel: viewModel, styleManager: styleManager, settings: settings)
                .onAppear {
                    appDelegate.readingViewModel = viewModel // 挂上才能在 Cmd+Q 时问脏文档
                }
        }
        .defaultSize(width: 1280, height: 860) // 默认双页阅读宽度
        .windowStyle(.hiddenTitleBar) // 标题画在书页顶栏里
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(BookL10n.string("action.new")) {
                    viewModel.document.newDocument() // 清空左页，不关窗
                }
                .bookMenuShortcut(BookKeyboardShortcuts.newDocument)

                Button(BookL10n.string("action.openFile")) {
                    viewModel.document.openFile() // 系统打开面板，单文件
                }
                .bookMenuShortcut(BookKeyboardShortcuts.openDocument)

                Button(BookL10n.string("action.openDirectory")) {
                    viewModel.document.openDirectory() // 打开目录浏览器
                }
                .disabled(viewModel.isRunning) // 模型跑着时不换书
            }

            CommandGroup(after: .saveItem) {
                Button(BookL10n.string("action.save")) {
                    viewModel.document.save()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.save)

                Button(BookL10n.string("action.saveAs")) {
                    viewModel.document.saveAs()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.saveAs)
                .disabled(viewModel.fileContent.isEmpty) // 空书不另存

                Button(BookL10n.string("action.saveAIBook")) {
                    viewModel.document.saveAsAIBook()
                }
                .disabled(viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(BookL10n.string("action.exportSelection")) {
                    viewModel.document.saveSelectionAs() // 只导出左页当前选区
                }
                .bookMenuShortcut(BookKeyboardShortcuts.exportSelection)
                .disabled(viewModel.selectedText.isEmpty)

                Button(BookL10n.string("action.explainSelection")) {
                    viewModel.assistant.explainSelection() // 右页讲解当前选区
                }
                .bookMenuShortcut(BookKeyboardShortcuts.explainSelection)

                Button(BookL10n.string("action.explainFull")) {
                    viewModel.assistant.explainFullText() // 整页原文讲解
                }
                .bookMenuShortcut(BookKeyboardShortcuts.explainFullText)
                .disabled(viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(BookL10n.string("menu.selectAllLeft")) {
                    viewModel.document.selectAllLeftPage()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.selectAllLeftPage)
                .disabled(viewModel.fileContent.isEmpty)

                Button(BookL10n.string("menu.selectAllTranslation")) {
                    viewModel.translation.selectAllRightPage() // 选中译文区，不是讲解
                }
                .bookMenuShortcut(BookKeyboardShortcuts.selectAllTranslation)
                .disabled(viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(
                    viewModel.assistant.isSpeakingExplanation
                        ? BookL10n.string("menu.stopSpeaking") // 正在读则变成停止
                        : BookL10n.string("menu.readOriginalSelectionOrFull")
                ) {
                    viewModel.assistant.readSelectionAloud() // 有选区读选区，否则读全文；朗读中再按即停
                }
                .bookMenuShortcut(BookKeyboardShortcuts.readOriginalSelectionOrFull)
                .disabled(viewModel.isRunning || (!viewModel.canReadAloud && !viewModel.assistant.isSpeakingExplanation))

                Button(BookL10n.string("menu.readOriginalFull")) {
                    viewModel.assistant.readOriginalFullTextAloud()
                }
                .disabled(
                    viewModel.isRunning
                        || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                Button(BookL10n.string("menu.readOriginalSelection")) {
                    viewModel.assistant.readOriginalSelectionAloud()
                }
                .disabled(viewModel.isRunning || viewModel.effectiveSelectedText.isEmpty)

                Button(BookL10n.string("menu.readTranslationFull")) {
                    viewModel.assistant.readTranslationFullTextAloud()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.readTranslationFull)
                .disabled(
                    viewModel.isRunning
                        || (viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && !viewModel.assistant.isSpeakingExplanation) // 没译文时仍允许停当前朗读
                )

                Button(BookL10n.string("menu.readTranslationSelection")) {
                    viewModel.assistant.readTranslationSelectionAloud()
                }
                .disabled(viewModel.isRunning || viewModel.effectiveLessonPlanSelectedText.isEmpty)

                Button(BookL10n.string("menu.readExplanationFull")) {
                    viewModel.assistant.readExplanationFullTextAloud()
                }
                .disabled(viewModel.isRunning || !viewModel.assistant.hasExplanationContent)

                Button(BookL10n.string("menu.readExplanationSelection")) {
                    viewModel.assistant.readExplanationSelectionAloud()
                }
                .disabled(viewModel.isRunning || viewModel.effectiveExplanationPanelSelectedText.isEmpty)

                Button(ClassicLiteratureSupplement.localizedCapabilityLabel) {
                    viewModel.assistant.supplementClassicLiterature() // 名著补充，不占用讲解历史
                }
                .bookMenuShortcut(BookKeyboardShortcuts.classicSupplement)
                .disabled(viewModel.fileContent.isEmpty || viewModel.isRunning)

                Button(BookL10n.string("action.evolution")) {
                    viewModel.evolution.startEvolution() // 正式改码入口，不用聊天里的「进化」空谈
                }
                .bookMenuShortcut(BookKeyboardShortcuts.evolution)
            }

            CommandGroup(replacing: .help) {
                Button(BookL10n.string("help.manual")) {
                    viewModel.openUserManual() // 应用内说明书
                }

                Button(BookL10n.string("help.manual.reveal")) {
                    BookUserManual.revealInFinder() // 揭示 md 文件，方便对照仓库
                }
                .disabled(BookUserManual.bundleURL == nil)
            }
        }
    }
}

/// 根视图：灌 ViewModel / 风格 / 本地化，语言世代变了通知阅读会话。
private struct AIBookRootView: View {
    @ObservedObject var viewModel: ReadingViewModel
    @ObservedObject var styleManager: BookStyleManager
    @ObservedObject var settings: AppSettings

    var body: some View {
        let _ = settings.localizationRevision // 观察哨，切语言重绘菜单和书页
        ContentView()
            .environmentObject(viewModel)
            .bookStyleEnvironment(styleManager)
            .bookLocalizationEnvironment()
            .onChange(of: settings.localizationRevision) { _ in
                viewModel.applyLanguageChange() // 刷新欢迎语等已拼好的中文缓存
            }
    }
}

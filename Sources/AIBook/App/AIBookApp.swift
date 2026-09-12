import SwiftUI

@main
struct AIBookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = ReadingViewModel()
    @ObservedObject private var styleManager = BookStyleManager.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            AIBookRootView(viewModel: viewModel, styleManager: styleManager, settings: settings)
                .onAppear {
                    appDelegate.readingViewModel = viewModel
                }
        }
        .defaultSize(width: 1280, height: 860)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(BookL10n.string("action.new")) {
                    viewModel.newDocument()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.newDocument)

                Button(BookL10n.string("action.openFile")) {
                    viewModel.openFile()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.openDocument)

                Button(BookL10n.string("action.openDirectory")) {
                    viewModel.openDirectory()
                }
                .disabled(viewModel.isRunning)
            }

            CommandGroup(after: .saveItem) {
                Button(BookL10n.string("action.save")) {
                    viewModel.save()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.save)

                Button(BookL10n.string("action.saveAs")) {
                    viewModel.saveAs()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.saveAs)
                .disabled(viewModel.fileContent.isEmpty)

                Button(BookL10n.string("action.exportSelection")) {
                    viewModel.saveSelectionAs()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.exportSelection)
                .disabled(viewModel.selectedText.isEmpty)

                Button(BookL10n.string("action.explainSelection")) {
                    viewModel.explainSelection()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.explainSelection)

                Button(BookL10n.string("action.explainFull")) {
                    viewModel.explainFullText()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.explainFullText)
                .disabled(viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(BookL10n.string("menu.selectAllLeft")) {
                    viewModel.selectAllLeftPage()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.selectAllLeftPage)
                .disabled(viewModel.fileContent.isEmpty)

                Button(BookL10n.string("menu.selectAllTranslation")) {
                    viewModel.selectAllRightPage()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.selectAllTranslation)
                .disabled(viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(
                    viewModel.isSpeakingExplanation
                        ? BookL10n.string("menu.stopSpeaking")
                        : BookL10n.string("menu.readOriginalSelectionOrFull")
                ) {
                    viewModel.readSelectionAloud()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.readOriginalSelectionOrFull)
                .disabled(viewModel.isRunning || (!viewModel.canReadAloud && !viewModel.isSpeakingExplanation))

                Button(BookL10n.string("menu.readOriginalFull")) {
                    viewModel.readOriginalFullTextAloud()
                }
                .disabled(
                    viewModel.isRunning
                        || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                Button(BookL10n.string("menu.readOriginalSelection")) {
                    viewModel.readOriginalSelectionAloud()
                }
                .disabled(viewModel.isRunning || viewModel.effectiveSelectedText.isEmpty)

                Button(BookL10n.string("menu.readTranslationFull")) {
                    viewModel.readTranslationFullTextAloud()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.readTranslationFull)
                .disabled(
                    viewModel.isRunning
                        || (viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && !viewModel.isSpeakingExplanation)
                )

                Button(BookL10n.string("menu.readTranslationSelection")) {
                    viewModel.readTranslationSelectionAloud()
                }
                .disabled(viewModel.isRunning || viewModel.effectiveLessonPlanSelectedText.isEmpty)

                Button(BookL10n.string("menu.readExplanationFull")) {
                    viewModel.readExplanationFullTextAloud()
                }
                .disabled(viewModel.isRunning || !viewModel.hasExplanationContent)

                Button(BookL10n.string("menu.readExplanationSelection")) {
                    viewModel.readExplanationSelectionAloud()
                }
                .disabled(viewModel.isRunning || viewModel.effectiveExplanationPanelSelectedText.isEmpty)

                Button(ClassicLiteratureSupplement.localizedCapabilityLabel) {
                    viewModel.supplementClassicLiterature()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.classicSupplement)
                .disabled(viewModel.fileContent.isEmpty || viewModel.isRunning)

                Button(BookL10n.string("action.evolution")) {
                    viewModel.startEvolution()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.evolution)
            }

            CommandGroup(replacing: .help) {
                Button(BookL10n.string("help.manual")) {
                    viewModel.openUserManual()
                }

                Button(BookL10n.string("help.manual.reveal")) {
                    BookUserManual.revealInFinder()
                }
                .disabled(BookUserManual.bundleURL == nil)
            }
        }
    }
}

private struct AIBookRootView: View {
    @ObservedObject var viewModel: ReadingViewModel
    @ObservedObject var styleManager: BookStyleManager
    @ObservedObject var settings: AppSettings

    var body: some View {
        let _ = settings.localizationRevision
        ContentView()
            .environmentObject(viewModel)
            .bookStyleEnvironment(styleManager)
            .bookLocalizationEnvironment()
            .onChange(of: settings.localizationRevision) { _ in
                viewModel.applyLanguageChange()
            }
    }
}

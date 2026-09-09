import SwiftUI

@main
struct AIBookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = ReadingViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(.light)
                .onAppear {
                    appDelegate.readingViewModel = viewModel
                }
        }
        .defaultSize(width: 1280, height: 860)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建") {
                    viewModel.newDocument()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.newDocument)

                Button("打开文本文件…") {
                    viewModel.openFile()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.openDocument)
            }

            CommandGroup(after: .saveItem) {
                Button("保存") {
                    viewModel.save()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.save)

                Button("另存为…") {
                    viewModel.saveAs()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.saveAs)
                .disabled(viewModel.fileContent.isEmpty)

                Button("导出选中为…") {
                    viewModel.saveSelectionAs()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.exportSelection)
                .disabled(viewModel.selectedText.isEmpty)

                Button("选择讲解") {
                    viewModel.explainSelection()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.explainSelection)

                Button("全文讲解") {
                    viewModel.explainFullText()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.explainFullText)
                .disabled(viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("全选左页") {
                    viewModel.selectAllLeftPage()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.selectAllLeftPage)
                .disabled(viewModel.fileContent.isEmpty)

                Button("全选翻译") {
                    viewModel.selectAllRightPage()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.selectAllTranslation)
                .disabled(viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(viewModel.isSpeakingExplanation ? "停止朗读" : "朗读原文（选中/全文）") {
                    viewModel.readSelectionAloud()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.readOriginalSelectionOrFull)
                .disabled(viewModel.isRunning || (!viewModel.canReadAloud && !viewModel.isSpeakingExplanation))

                Button("朗读原文全文") {
                    viewModel.readOriginalFullTextAloud()
                }
                .disabled(
                    viewModel.isRunning
                        || viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                Button("朗读原文选中") {
                    viewModel.readOriginalSelectionAloud()
                }
                .disabled(viewModel.isRunning || viewModel.effectiveSelectedText.isEmpty)

                Button("朗读翻译全文") {
                    viewModel.readTranslationFullTextAloud()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.readTranslationFull)
                .disabled(
                    viewModel.isRunning
                        || (viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && !viewModel.isSpeakingExplanation)
                )

                Button("朗读翻译选择") {
                    viewModel.readTranslationSelectionAloud()
                }
                .disabled(viewModel.isRunning || viewModel.effectiveLessonPlanSelectedText.isEmpty)

                Button("朗读讲解全文") {
                    viewModel.readExplanationFullTextAloud()
                }
                .disabled(viewModel.isRunning || !viewModel.hasExplanationContent)

                Button("朗读讲解选中") {
                    viewModel.readExplanationSelectionAloud()
                }
                .disabled(viewModel.isRunning || viewModel.effectiveExplanationPanelSelectedText.isEmpty)

                Button(ClassicLiteratureSupplement.capabilityLabel) {
                    viewModel.supplementClassicLiterature()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.classicSupplement)
                .disabled(viewModel.fileContent.isEmpty || viewModel.isRunning)

                Button("自我进化") {
                    viewModel.startEvolution()
                }
                .bookMenuShortcut(BookKeyboardShortcuts.evolution)
            }
        }
    }
}

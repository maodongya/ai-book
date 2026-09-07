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
                .keyboardShortcut("n")

                Button("打开文本文件…") {
                    viewModel.openFile()
                }
                .keyboardShortcut("o")
            }

            CommandGroup(after: .saveItem) {
                Button("保存") {
                    viewModel.save()
                }
                .keyboardShortcut("s")

                Button("另存为…") {
                    viewModel.saveAs()
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])
                .disabled(viewModel.fileContent.isEmpty)

                Button("导出选中为…") {
                    viewModel.saveSelectionAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(viewModel.selectedText.isEmpty)

                Button("选择讲解") {
                    viewModel.explainSelection()
                }
                .keyboardShortcut("r")

                Button("全文讲解") {
                    viewModel.explainFullText()
                }
                .keyboardShortcut("R", modifiers: [.command, .shift])
                .disabled(viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("全选左页") {
                    viewModel.selectAllLeftPage()
                }
                .keyboardShortcut("a", modifiers: [.command, .control])
                .disabled(viewModel.fileContent.isEmpty)

                Button("全选翻译") {
                    viewModel.selectAllRightPage()
                }
                .keyboardShortcut("a", modifiers: [.command, .control, .shift])
                .disabled(viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(viewModel.isSpeakingExplanation ? "停止朗读" : "朗读（选中/全文）") {
                    viewModel.readSelectionAloud()
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
                .disabled(viewModel.isRunning || !viewModel.canReadAloud)

                Button(viewModel.isSpeakingExplanation ? "停止朗读" : "朗读翻译") {
                    viewModel.readLessonPlanAloud()
                }
                .keyboardShortcut("t", modifiers: [.command, .option])
                .disabled(
                    viewModel.isRunning
                        || (viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && !viewModel.isSpeakingExplanation)
                )

                Button(ClassicLiteratureSupplement.capabilityLabel) {
                    viewModel.supplementClassicLiterature()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(viewModel.fileContent.isEmpty || viewModel.isRunning)

                Button("自我进化") {
                    viewModel.startEvolution()
                }
                .keyboardShortcut("e")
            }
        }
    }
}

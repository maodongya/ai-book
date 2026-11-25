import SwiftUI

/// 页顶标题和菜单。菜单贴在麦克风左边。
struct IOSPageHeading<Menu: View>: View {
    let titleKey: String
    @ObservedObject var shell: IOSShellModel
    var showsPageMenu: Bool
    @ViewBuilder var menu: () -> Menu

    var body: some View {
        HStack(spacing: 8) {
            if showsPageMenu {
                IOSBubbleMenu(shell: shell) // 左侧换页，样式与右侧更多相同
            }
            Text(BookL10n.string(titleKey))
                .font(.title2.weight(.semibold))
                .foregroundStyle(IOSPaper.ink)
            Spacer()
            menu()
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.trailing, 36) // 给右上角麦克风让开
    }
}

/// 原文页菜单。对应 Mac 的文档菜单：新建、打开、保存、另存、补充和阅读。
struct IOSDocumentMenu: View {
    @ObservedObject var document: IOSDocument
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var settings: IOSModelSettings
    @ObservedObject var service: IOSReadingService
    @ObservedObject var speaker: IOSSpeaker
    @State private var confirmNew = false

    var body: some View {
        Menu {
            Button(BookL10n.string("action.newSource")) {
                if document.dirty {
                    confirmNew = true // 改过先问一声
                } else {
                    document.newDocument()
                }
            }
            Button(BookL10n.string("action.openFile")) {
                document.libraryPresented = true // 先列出应用里的文本
            }
            Button(BookL10n.string("action.openDirectoryShort")) {
                document.importKind = .directory // 只选文件夹
            }
            Divider()
            Button(BookL10n.string("action.saveSource")) {
                document.exportKind = .text
            }
            .disabled(!document.hasSource)
            Button(BookL10n.string("action.saveSourceAs")) {
                document.exportKind = .saveAs // iOS 没有当前路径，另存仍交给系统
            }
            .disabled(!document.hasSource)
            Button(BookL10n.string("action.saveAIBook")) {
                document.exportKind = .aibook
            }
            .disabled(!document.hasSource)
            Button(BookL10n.string("action.exportSelection")) {
                document.exportKind = .selection
            }
            .disabled(document.selection.isEmpty)
            Button(BookL10n.string("action.selectAllSource")) {
                document.selection = document.source // 全选成为下一次讲解的选区
            }
            .disabled(!document.hasSource)
            Divider()
            Button(BookL10n.string("action.classicSupplement")) {
                guard document.hasSource else { return }
                if settings.isReady {
                    service.supplement(document: document, settings: settings)
                } else {
                    shell.select(.settings) // 补全也要模型
                }
            }
            .disabled(!document.hasSource || service.running)
            Button(BookL10n.string("action.enterReading")) {
                shell.enterReading()
            }
            .disabled(!document.hasSource)
            IOSSpeechMenu(document: document, speaker: speaker)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(IOSPaper.ink)
        }
        .accessibilityLabel(BookL10n.string("menu.document"))
        .confirmationDialog(BookL10n.string("action.newSource"), isPresented: $confirmNew, titleVisibility: .visible) {
            Button(BookL10n.string("action.newSource"), role: .destructive) {
                document.newDocument() // 确认后才清掉未保存的原文
            }
            Button(BookL10n.string("alert.cancel"), role: .cancel) {}
        }
    }
}

/// 讲解页菜单。生成、打开、保存、清空和朗读。
struct IOSExplanationMenu: View {
    @ObservedObject var document: IOSDocument
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var settings: IOSModelSettings
    @ObservedObject var service: IOSReadingService
    @ObservedObject var speaker: IOSSpeaker

    var body: some View {
        Menu {
            Button(BookL10n.string("action.explainSelection")) {
                beginExplain(selectionOnly: true)
            }
            .disabled(settings.isReady && document.selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(BookL10n.string("action.explainFull")) {
                beginExplain(selectionOnly: false)
            }
            .disabled(settings.isReady && !document.hasSource)
            Divider()
            Button(BookL10n.string("action.newExplanation")) {
                document.clearExplanation() // 只留空页，原文不动
            }
            .disabled(service.running)
            Button(BookL10n.string("action.openExplanation")) {
                document.importKind = .explanation
            }
            .disabled(service.running)
            Button(BookL10n.string("action.saveExplanation")) {
                document.exportKind = .explanation
            }
            .disabled(document.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(BookL10n.string("action.selectAllExplanation")) {
                document.explanationSelection = document.explanation
            }
            .disabled(document.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(BookL10n.string("action.clearExplanation"), role: .destructive) {
                document.clearExplanation()
            }
            .disabled(service.running || document.explanation.isEmpty)
            Divider()
            Button(speaker.speaking ? BookL10n.string("action.stop") : BookL10n.string("action.readExplanation")) {
                if speaker.speaking {
                    speaker.stop()
                } else {
                    speaker.speak(document.explanation)
                }
            }
            .disabled(!speaker.speaking && document.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            IOSSpeechMenu(document: document, speaker: speaker)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(IOSPaper.ink)
        }
        .accessibilityLabel(BookL10n.string("menu.explanation"))
    }

    /// 没配模型就去设置，配好了再按选区或全文讲解。
    private func beginExplain(selectionOnly: Bool) {
        if !settings.isReady {
            shell.select(.settings)
            return
        }
        service.explain(document: document, settings: settings, selectionOnly: selectionOnly)
    }
}

/// 翻译页菜单。逐字、整段、打开、保存和清空。
struct IOSTranslationMenu: View {
    @ObservedObject var document: IOSDocument
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var settings: IOSModelSettings
    @ObservedObject var service: IOSReadingService
    @ObservedObject var speaker: IOSSpeaker

    var body: some View {
        Menu {
            Button(BookL10n.string("action.wordTranslation")) {
                begin(paragraph: false)
            }
            .disabled(settings.isReady && !document.hasSource)
            Button(BookL10n.string("action.paragraphTranslation")) {
                begin(paragraph: true)
            }
            .disabled(settings.isReady && !document.hasSource)
            Button(speaker.speaking ? BookL10n.string("action.stop") : BookL10n.string("action.readTranslation")) {
                if speaker.speaking {
                    speaker.stop()
                } else {
                    speaker.speak(document.translation)
                }
            }
            .disabled(!speaker.speaking && document.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(BookL10n.string("action.selectAllTranslation")) {
                document.translationSelection = document.translation
            }
            .disabled(document.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Divider()
            Button(BookL10n.string("action.openTranslation")) {
                document.importKind = .translation
            }
            .disabled(service.running)
            Button(BookL10n.string("action.saveTranslation")) {
                document.exportKind = .translation
            }
            .disabled(document.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(BookL10n.string("action.clearTranslation"), role: .destructive) {
                document.clearTranslation()
            }
            .disabled(service.running || document.translation.isEmpty)
            IOSSpeechMenu(document: document, speaker: speaker)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(IOSPaper.ink)
        }
        .accessibilityLabel(BookL10n.string("menu.translation"))
    }

    /// 没配模型就去设置。
    private func begin(paragraph: Bool) {
        if !settings.isReady {
            shell.select(.settings)
            return
        }
        service.translate(document: document, settings: settings, paragraph: paragraph)
    }
}

/// 朗读子菜单。原文、译文、讲解各分全文和选区。
struct IOSSpeechMenu: View {
    @ObservedObject var document: IOSDocument
    @ObservedObject var speaker: IOSSpeaker

    var body: some View {
        Menu(BookL10n.string("menu.speech")) {
            Button(BookL10n.string("menu.readOriginalFull")) {
                speaker.speak(document.source)
            }
            .disabled(!document.hasSource)
            Button(BookL10n.string("menu.readOriginalSelection")) {
                speaker.speak(document.selection)
            }
            .disabled(document.selection.isEmpty)
            Divider()
            Button(BookL10n.string("menu.readTranslationFull")) {
                speaker.speak(document.translation)
            }
            .disabled(document.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(BookL10n.string("menu.readTranslationSelection")) {
                speaker.speak(document.translationSelection)
            }
            .disabled(document.translationSelection.isEmpty)
            Divider()
            Button(BookL10n.string("menu.readExplanationFull")) {
                speaker.speak(document.explanation)
            }
            .disabled(document.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(BookL10n.string("menu.readExplanationSelection")) {
                speaker.speak(document.explanationSelection)
            }
            .disabled(document.explanationSelection.isEmpty)
        }
    }
}

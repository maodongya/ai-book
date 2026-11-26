import SwiftUI

/// 页顶标题。菜单与麦克风在根级顶栏 safeAreaInset。
struct IOSPageHeading: View {
    let titleKey: String

    var body: some View {
        HStack(spacing: 8) {
            Text(BookL10n.string(titleKey))
                .font(.title2.weight(.semibold))
                .foregroundStyle(IOSPaper.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, IOSLayout.pageTitleHorizontalPadding)
        .padding(.top, IOSLayout.pageTitleTopPadding)
    }
}

/// 全书区块：设置、说明书、隐私、保存包。
struct IOSBookMenuItems: View {
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var document: IOSDocument
    @Binding var showManual: Bool
    @Binding var showPrivacy: Bool

    var body: some View {
        Group {
            Button(BookL10n.string("settings.book")) {
                shell.select(.settings)
            }
            Button(BookL10n.string("help.manual")) {
                showManual = true
            }
            Button(BookL10n.string("privacy.policy.title")) {
                showPrivacy = true
            }
            Button(BookL10n.string("action.saveAIBook")) {
                document.exportKind = .aibook
            }
            .disabled(!document.hasSource)
        }
    }
}

/// 原文页菜单条目。对应 Mac 的文档菜单。
struct IOSDocumentMenuItems: View {
    @ObservedObject var document: IOSDocument
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var settings: IOSModelSettings
    @ObservedObject var service: IOSReadingService
    @ObservedObject var speaker: IOSSpeaker
    @Binding var confirmNew: Bool

    var body: some View {
        Group {
            Button(BookL10n.string("action.newSource")) {
                if document.dirty {
                    confirmNew = true // 改过先问一声
                } else {
                    document.newDocument()
                }
            }
            Button(BookL10n.string("action.openFile")) {
                document.libraryPresented = true
            }
            Button(BookL10n.string("action.openDirectoryShort")) {
                document.importKind = .directory
            }
            Button(BookL10n.string("action.saveSource")) {
                document.exportKind = .text
            }
            .disabled(!document.hasSource)
            Button(BookL10n.string("action.saveSourceAs")) {
                document.exportKind = .saveAs
            }
            .disabled(!document.hasSource)
            Button(BookL10n.string("action.exportSelection")) {
                document.exportKind = .selection
            }
            .disabled(document.selection.isEmpty)
            Button(BookL10n.string("action.selectAllSource")) {
                document.selection = document.source
            }
            .disabled(!document.hasSource)
            Button(BookL10n.string("action.classicSupplement")) {
                guard document.hasSource else { return }
                if settings.isReady {
                    service.supplement(document: document, settings: settings)
                } else {
                    shell.select(.settings)
                }
            }
            .disabled(!document.hasSource || service.running)
            Button(BookL10n.string("action.enterReading")) {
                shell.enterReading()
            }
            .disabled(!document.hasSource)
            IOSSpeechMenu(document: document, speaker: speaker)
        }
    }
}

/// 讲解页菜单条目。
struct IOSExplanationMenuItems: View {
    @ObservedObject var document: IOSDocument
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var settings: IOSModelSettings
    @ObservedObject var service: IOSReadingService
    @ObservedObject var speaker: IOSSpeaker

    var body: some View {
        Group {
            Button(BookL10n.string("action.explainSelection")) {
                beginExplain(selectionOnly: true)
            }
            .disabled(settings.isReady && document.selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(BookL10n.string("action.explainFull")) {
                beginExplain(selectionOnly: false)
            }
            .disabled(settings.isReady && !document.hasSource)
            Button(BookL10n.string("action.newExplanation")) {
                document.clearExplanation()
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
            if !document.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(BookL10n.string("explanation.alignSource")) {
                    document.alignExplanationToSource()
                }
            }
            if let alignment = document.explanationAlignment {
                if alignment.isLocked {
                    Button(BookL10n.string("operation.action.unlockExplanation")) {
                        document.setExplanationAlignmentLocked(false)
                    }
                } else {
                    Button(BookL10n.string("operation.action.lockExplanation")) {
                        document.setExplanationAlignmentLocked(true)
                    }
                }
            }
            Button(speaker.speaking ? BookL10n.string("action.stop") : BookL10n.string("action.readExplanation")) {
                if speaker.speaking {
                    speaker.stop()
                } else {
                    speaker.speak(document.explanation, contextTitleKey: "target.explanation")
                }
            }
            .disabled(!speaker.speaking && document.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            IOSSpeechMenu(document: document, speaker: speaker)
        }
    }

    private func beginExplain(selectionOnly: Bool) {
        if !settings.isReady {
            shell.select(.settings)
            return
        }
        service.explain(document: document, settings: settings, selectionOnly: selectionOnly)
    }
}

/// 翻译页菜单条目。
struct IOSTranslationMenuItems: View {
    @ObservedObject var document: IOSDocument
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var settings: IOSModelSettings
    @ObservedObject var service: IOSReadingService
    @ObservedObject var speaker: IOSSpeaker

    var body: some View {
        Group {
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
                    speaker.speak(document.translation, contextTitleKey: "target.translation")
                }
            }
            .disabled(!speaker.speaking && document.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(BookL10n.string("action.selectAllTranslation")) {
                document.translationSelection = document.translation
            }
            .disabled(document.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            if !document.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(BookL10n.string("translation.alignSource")) {
                    document.alignTranslationToSource()
                }
            }
            if let alignment = document.translationAlignment {
                if alignment.isLocked {
                    Button(BookL10n.string("operation.action.unlockTranslation")) {
                        document.setTranslationAlignmentLocked(false)
                    }
                } else {
                    Button(BookL10n.string("operation.action.lockTranslation")) {
                        document.setTranslationAlignmentLocked(true)
                    }
                }
            }
            IOSSpeechMenu(document: document, speaker: speaker)
        }
    }

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
                speaker.speak(document.source, contextTitleKey: "context.label.source")
            }
            .disabled(!document.hasSource)
            Button(BookL10n.string("menu.readOriginalSelection")) {
                speaker.speak(document.selection, contextTitleKey: "context.label.source")
            }
            .disabled(document.selection.isEmpty)
            Divider()
            Button(BookL10n.string("menu.readTranslationFull")) {
                speaker.speak(document.translation, contextTitleKey: "target.translation")
            }
            .disabled(document.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(BookL10n.string("menu.readTranslationSelection")) {
                speaker.speak(document.translationSelection, contextTitleKey: "target.translation")
            }
            .disabled(document.translationSelection.isEmpty)
            Divider()
            Button(BookL10n.string("menu.readExplanationFull")) {
                speaker.speak(document.explanation, contextTitleKey: "target.explanation")
            }
            .disabled(document.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(BookL10n.string("menu.readExplanationSelection")) {
                speaker.speak(document.explanationSelection, contextTitleKey: "target.explanation")
            }
            .disabled(document.explanationSelection.isEmpty)
        }
    }
}
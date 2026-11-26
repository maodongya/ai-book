import Foundation

/// 把听写口令执行到 iOS 的页、朗读和模型请求上。对不上的口令只显示原文。
@MainActor
final class IOSVoiceController: ObservableObject {
    @Published var holding = false
    @Published var heard = ""
    private let listener = IOSSpeechListener()
    private var shell: IOSShellModel?
    private var document: IOSDocument?
    private var settings: IOSModelSettings?
    private var service: IOSReadingService?
    private var speaker: IOSSpeaker?
    private var heardClearTask: Task<Void, Never>?

    /// 根界面创建完各页之后挂上。这些对象和界面是同一份。
    func bind(
        shell: IOSShellModel,
        document: IOSDocument,
        settings: IOSModelSettings,
        service: IOSReadingService,
        speaker: IOSSpeaker
    ) {
        self.shell = shell
        self.document = document
        self.settings = settings
        self.service = service
        self.speaker = speaker
    }

    /// 按下麦克风。
    func beginHold() {
        holding = true
        heard = BookL10n.string("operation.listening")
        do {
            try listener.start()
        } catch {
            heard = BookL10n.string("operation.speech.needsPermission")
            holding = false
        }
    }

    /// 松开后匹配口令。高置信度的本地口令直接做，不再请求模型。
    func endHold() {
        holding = false
        let text = listener.stop().trimmingCharacters(in: .whitespacesAndNewlines)
        heard = text
        scheduleHeardClear()
        guard !text.isEmpty, let plan = OperationPhraseMatch.localPlan(for: text) else { return }
        for action in plan.actions {
            perform(action) // 一句里可能有连续两步，按顺序做
        }
    }

    /// 口令对应的 iOS 动作。Mac 专有的分栏和锁定这里跳过。
    private func perform(_ action: OperationAction) {
        guard let shell, let document, let settings, let service, let speaker else { return }
        switch action {
        case .explainSelection:
            shell.select(.explanation)
            service.explain(document: document, settings: settings, selectionOnly: true)
        case .explainFullText:
            shell.select(.explanation)
            service.explain(document: document, settings: settings, selectionOnly: false)
        case .translateWordByWord:
            shell.select(.translation)
            service.translate(document: document, settings: settings, paragraph: false)
        case .translateParagraph:
            shell.select(.translation)
            service.translate(document: document, settings: settings, paragraph: true)
        case .readOriginalSelection:
            speaker.speak(document.selection, contextTitleKey: "context.label.source")
        case .readOriginalFull:
            speaker.speak(document.source, contextTitleKey: "context.label.source")
        case .readTranslationSelection:
            speaker.speak(document.translationSelection, contextTitleKey: "target.translation")
        case .readTranslationFull:
            speaker.speak(document.translation, contextTitleKey: "target.translation")
        case .readExplanationSelection:
            speaker.speak(document.explanationSelection, contextTitleKey: "target.explanation")
        case .readExplanationFull:
            speaker.speak(document.explanation, contextTitleKey: "target.explanation")
        case .pauseSpeech:
            speaker.pause()
        case .resumeSpeech:
            speaker.resume()
        case .stopSpeech:
            speaker.stop()
        case .stopCurrentRun:
            service.cancel()
        case .toggleReadingMode:
            if shell.page == .reading {
                shell.exitReading()
            } else {
                shell.enterReading()
            }
        case .showAssistantPanel(let panel):
            shell.select(panel == "translation" ? .translation : .explanation)
        case .supplementClassic:
            shell.select(.source)
            service.supplement(document: document, settings: settings)
        case .selectAllLeft:
            document.selection = document.source
        case .save:
            document.exportKind = .text // 原文页看到后交给系统导出
        case .saveAsAIBook(_):
            document.exportKind = .aibook
        case .alignTranslation:
            shell.select(.translation)
            document.alignTranslationToSource()
        case .alignExplanation:
            shell.select(.explanation)
            document.alignExplanationToSource()
        case .lockTranslation:
            shell.select(.translation)
            document.setTranslationAlignmentLocked(true)
        case .unlockTranslation:
            shell.select(.translation)
            document.setTranslationAlignmentLocked(false)
        case .lockExplanation:
            shell.select(.explanation)
            document.setExplanationAlignmentLocked(true)
        case .unlockExplanation:
            shell.select(.explanation)
            document.setExplanationAlignmentLocked(false)
        default:
            break // 目录、对照表开关等仍走按钮
        }
    }

  private func scheduleHeardClear() {
        heardClearTask?.cancel()
        heardClearTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            heard = ""
        }
    }
}

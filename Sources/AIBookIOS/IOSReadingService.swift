import Foundation

/// 在 iOS 上发起讲解、翻译、补全和追问。同一时间只跑一路。
@MainActor
final class IOSReadingService: ObservableObject {
    /// 正在等模型。
    @Published private(set) var running = false
    /// 页顶能看见的一句话。
    @Published var status = ""
    weak var speaker: IOSSpeaker?
    private var task: Task<Void, Never>?

    private var speaksAfterGeneration: Bool {
        UserDefaults.standard.bool(forKey: "aiBook.ios.speakAfterGeneration")
    }

    /// 讲解选区或全文。没配模型时不发请求。非追问时按设置里的讲解语言串行生成。
    func explain(document: IOSDocument, settings: IOSModelSettings, selectionOnly: Bool, followUp: String? = nil) {
        let source = selectionOnly ? document.selection : document.source
        guard settings.isReady else {
            status = BookL10n.string("help.configureBookLLM") // 先去设置
            return
        }
        let isFollowUp = followUp?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        if isFollowUp {
            let target = TranslationTargetLanguage(rawValue: document.activeLanguageID)
                ?? TranslationTargetLanguage.matching(appLanguage: BookL10n.currentLanguage)
            let prompt = IOSReadingPrompt.explain(source: source, target: target, followUp: followUp)
            let base = document.explanation
            run(status: BookL10n.string("explanation.progress.hint"), settings: settings, prompt: prompt) { text in
                if base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    document.storeExplanation(text)
                } else {
                    document.appendExplanation(text)
                }
            } onPartial: { partial in
                if base.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    document.storeExplanation(partial)
                } else {
                    document.storeExplanation(base + "\n\n" + partial)
                }
            }
            return
        }
        let targets = ExplanationTargetLanguageStore.loadSelection(appLanguage: BookL10n.currentLanguage)
        guard !targets.isEmpty else {
            status = BookL10n.string("vm.error.explanationLanguageMissing")
            return
        }
        let startingLanguage = document.activeLanguageID
        let hint = BookL10n.string("explanation.progress.hint")
        runLanguages(
            document: document,
            targets: targets,
            startingLanguageID: startingLanguage,
            settings: settings,
            speakContextKey: "target.explanation"
        ) { [self] target, index, count in
            document.selectLanguage(target.rawValue)
            let scope = self.languageScopeTitle(target, index: index, count: count)
            let prompt = IOSReadingPrompt.explain(source: source, target: target, followUp: nil)
            let line = scope.isEmpty ? hint : scope
            return (
                status: line,
                prompt: prompt,
                apply: { text in document.storeExplanation(text) },
                onPartial: { partial in document.storeExplanation(partial) }
            )
        }
    }

    /// 逐字或整段。源文本优先选区。整段翻译按设置里的译文语言串行生成。
    func translate(document: IOSDocument, settings: IOSModelSettings, paragraph: Bool) {
        let selected = document.selection.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = selected.isEmpty ? document.source : selected // 没有选区就用全文
        guard settings.isReady else {
            status = BookL10n.string("help.configureBookLLM")
            return
        }
        if paragraph {
            let targets = TranslationTargetLanguageStore.loadSelection(appLanguage: BookL10n.currentLanguage)
            guard !targets.isEmpty else {
                status = BookL10n.string("vm.error.translationLanguageMissing")
                return
            }
            let startingLanguage = document.activeLanguageID
            let hint = BookL10n.string("translation.progress.hint")
            runLanguages(
                document: document,
                targets: targets,
                startingLanguageID: startingLanguage,
                settings: settings,
                speakContextKey: "target.translation"
            ) { [self] target, index, count in
                document.selectLanguage(target.rawValue)
                let scope = self.languageScopeTitle(target, index: index, count: count)
                let prompt = IOSReadingPrompt.translate(source: source, paragraph: true, target: target)
                let line = scope.isEmpty ? hint : scope
                return (
                    status: line,
                    prompt: prompt,
                    apply: { text in document.storeTranslation(text) },
                    onPartial: { partial in document.storeTranslation(partial) }
                )
            }
            return
        }
        let target = TranslationTargetLanguage(rawValue: document.activeLanguageID)
            ?? TranslationTargetLanguage.matching(appLanguage: BookL10n.currentLanguage)
        let prompt = IOSReadingPrompt.translate(source: source, paragraph: false, target: target)
        run(status: BookL10n.string("translation.progress.hint"), settings: settings, prompt: prompt) { text in
            document.storeTranslation(text)
        } onPartial: { partial in
            document.storeTranslation(partial)
        }
    }

    /// 把原文补成完整篇章。有选区只替换选区，和 Mac 一样。
    func supplement(document: IOSDocument, settings: IOSModelSettings) {
        let selected = document.selection.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = selected.isEmpty ? document.source : selected // 选区优先
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = BookL10n.string("vm.error.classicsPasteFirst") // 先有节选
            return
        }
        guard settings.isReady else {
            status = BookL10n.string("help.configureBookLLM")
            return
        }
        let prompt = IOSReadingPrompt.supplement(source: source, selection: !selected.isEmpty)
        run(status: BookL10n.string("action.classicSupplement"), settings: settings, prompt: prompt) { text in
            document.applySupplement(IOSReadingPrompt.supplementBody(from: text)) // 只写回标记里的正文
        }
    }

    /// 停掉这一轮。
    func cancel() {
        task?.cancel() // URLSession 会跟着任务取消
        task = nil
        running = false
        status = BookL10n.string("action.stop")
    }

    /// 多种语言串行请求。中途失败会停在这一种上。
    private func runLanguages(
        document: IOSDocument,
        targets: [TranslationTargetLanguage],
        startingLanguageID: String,
        settings: IOSModelSettings,
        speakContextKey: String,
        step: @escaping (
            _ target: TranslationTargetLanguage,
            _ index: Int,
            _ count: Int
        ) -> (
            status: String,
            prompt: (system: String, user: String),
            apply: (String) -> Void,
            onPartial: ((String) -> Void)?
        )
    ) {
        task?.cancel()
        running = true
        task = Task {
            defer { running = false }
            var lastSpoken = ""
            do {
                let count = targets.count
                for (offset, target) in targets.enumerated() {
                    try Task.checkCancellation()
                    let index = offset + 1
                    let slice = step(target, index, count)
                    status = slice.status
                    let text = try await IOSChatClient.complete(
                        system: slice.prompt.system,
                        user: slice.prompt.user,
                        settings: settings,
                        onPartial: slice.onPartial
                    )
                    guard !Task.isCancelled else { return }
                    slice.apply(text)
                    lastSpoken = text
                }
                status = ""
                document.selectLanguage(startingLanguageID)
                if speaksAfterGeneration, !lastSpoken.isEmpty, let speaker {
                    speaker.speak(lastSpoken, contextTitleKey: speakContextKey)
                }
            } catch is CancellationError {
                status = BookL10n.string("action.stop")
            } catch {
                status = IOSLLMErrorMessage.message(for: error)
            }
        }
    }

    private func languageScopeTitle(
        _ language: TranslationTargetLanguage,
        index: Int,
        count: Int
    ) -> String {
        guard count > 1 else { return "" }
        return BookL10n.format("translation.progress.language", language.localizedName, index, count)
    }

    /// 包一层任务，成功才写回正文。
    private func run(
        status: String,
        settings: IOSModelSettings,
        prompt: (system: String, user: String),
        apply: @escaping (String) -> Void,
        onPartial: ((String) -> Void)? = nil
    ) {
        task?.cancel()
        running = true
        self.status = status
        task = Task {
            do {
                let text = try await IOSChatClient.complete(
                    system: prompt.system,
                    user: prompt.user,
                    settings: settings,
                    onPartial: onPartial
                )
                guard !Task.isCancelled else { return }
                apply(text)
                self.status = ""
            } catch is CancellationError {
                self.status = BookL10n.string("action.stop")
            } catch {
                self.status = IOSLLMErrorMessage.message(for: error)
            }
            running = false
        }
    }
}

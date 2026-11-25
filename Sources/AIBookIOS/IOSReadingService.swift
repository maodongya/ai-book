import Foundation

/// 在 iOS 上发起讲解、翻译、补全和追问。同一时间只跑一路。
@MainActor
final class IOSReadingService: ObservableObject {
    /// 正在等模型。
    @Published private(set) var running = false
    /// 页顶能看见的一句话。
    @Published var status = ""
    private var task: Task<Void, Never>?

    /// 讲解选区或全文。没配模型时不发请求。
    func explain(document: IOSDocument, settings: IOSModelSettings, selectionOnly: Bool, followUp: String? = nil) {
        let source = selectionOnly ? document.selection : document.source
        guard settings.isReady else {
            status = BookL10n.string("help.configureBookLLM") // 先去设置
            return
        }
        let prompt = IOSReadingPrompt.explain(source: source, followUp: followUp)
        run(status: BookL10n.string("explanation.progress.hint"), settings: settings, prompt: prompt) { text in
            document.storeExplanation(text) // 整段替换成这一次的讲解，并记在当前语言下
        }
    }

    /// 逐字或整段。源文本优先选区。
    func translate(document: IOSDocument, settings: IOSModelSettings, paragraph: Bool) {
        let selected = document.selection.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = selected.isEmpty ? document.source : selected // 没有选区就用全文
        guard settings.isReady else {
            status = BookL10n.string("help.configureBookLLM")
            return
        }
        let prompt = IOSReadingPrompt.translate(source: source, paragraph: paragraph)
        run(status: BookL10n.string("translation.progress.hint"), settings: settings, prompt: prompt) { text in
            document.storeTranslation(text) // 译文记在当前语言下
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

    /// 包一层任务，成功才写回正文。
    private func run(
        status: String,
        settings: IOSModelSettings,
        prompt: (system: String, user: String),
        apply: @escaping (String) -> Void
    ) {
        task?.cancel() // 新的一轮替换旧的
        running = true
        self.status = status
        task = Task {
            do {
                let text = try await IOSChatClient.complete(system: prompt.system, user: prompt.user, settings: settings)
                guard !Task.isCancelled else { return }
                apply(text)
                self.status = ""
            } catch is CancellationError {
                self.status = BookL10n.string("action.stop")
            } catch {
                self.status = error.localizedDescription // 网络和 HTTP 原文直接给读者
            }
            running = false
        }
    }
}

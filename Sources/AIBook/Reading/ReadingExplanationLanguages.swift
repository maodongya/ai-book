import Foundation

@MainActor
/// 右页讲解的多语言：勾选决定下次生成哪些，显示语言决定当前看哪一种。
final class ReadingExplanationLanguages {
    unowned let document: ReadingDocumentSession // 语言包和当前讲解正文都在文档会话上

    init(document: ReadingDocumentSession) {
        self.document = document // 不另存一份语言包
    }

    /// 右页正在显示的讲解语言。
    var displayed: TranslationTargetLanguage {
        if let id = document.bundledExplanationLanguageID, // 本轮记住的语言优先
           let language = TranslationTargetLanguage(rawValue: id),
           language != .followAppLanguage {
            return language // 具体语言
        }
        return AppSettings.shared.resolvedExplanationTargetLanguage // 还没装过包时用设置
    }

    /// 语言包里已经有讲解、可以切换显示的语言。
    var availableToShow: [TranslationTargetLanguage] {
        TranslationTargetLanguage.selectableTargets.filter { language in // 菜单顺序
            document.bundledLanguages[language.rawValue]?.hasExplanation == true // 空讲解不列出
        }
    }

    /// 把当前右页讲解记到指定语言。
    func capture(languageID: String) {
        guard AIBookBundle.isLanguageID(languageID) else { return } // 跟随项不能当目录
        document.bundledExplanationLanguageID = languageID // 下次快照写这一栏
        document.snapshotActiveBundledLanguages() // 其它语言不动
    }

    /// 右页已有讲解但还没进语言包时，记到当前显示语言下。
    func adoptDisplayedIfNeeded() {
        let text = document.host.assistant.bundledExplanationExportText()
            .trimmingCharacters(in: .whitespacesAndNewlines) // 只有欢迎不算
        guard !text.isEmpty else { return } // 空屏幕不覆盖包
        let id = displayed.rawValue // 当前看着的语言
        guard AIBookBundle.isLanguageID(id) else { return }
        if document.bundledLanguages[id]?.hasExplanation == true { return } // 包里已有则不覆盖
        capture(languageID: id) // 补进语言包
    }

    /// 生成多种语言前，先把屏幕上的讲解留在它自己的语言里。
    func preserveDisplayed() {
        let text = document.host.assistant.bundledExplanationExportText()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return } // 没有正文不必写
        capture(languageID: displayed.rawValue) // 避免下一种语言盖掉这一份
    }

    /// 换上某种语言已有的讲解。不把当前屏幕写回去。
    func present(_ language: TranslationTargetLanguage) {
        guard AIBookBundle.isLanguageID(language.rawValue) else { return }
        document.bundledExplanationLanguageID = language.rawValue // 后续成功才写回这一栏
        let payload = document.bundledLanguages[language.rawValue] // 没有则空白
        let text = payload?.hasExplanation == true ? (payload?.explanationText ?? "") : "" // 没讲解就空页
        let alignment = payload?.hasExplanation == true ? payload?.explanationAlignment : nil // 空页不带旧对齐
        document.host.assistant.installBundledExplanation(text: text, alignment: alignment) // 右页换成这一语言
    }

    /// 切换右页显示的讲解。先写回当前语言，再装入所选语言。
    func show(_ language: TranslationTargetLanguage) {
        guard AIBookBundle.isLanguageID(language.rawValue) else { return }
        let current = displayed // 写回用
        if current != language {
            capture(languageID: current.rawValue) // 先留下正在看的
        }
        guard let payload = document.bundledLanguages[language.rawValue], payload.hasExplanation else { return } // 没内容不切
        document.bundledExplanationLanguageID = language.rawValue
        document.host.assistant.installBundledExplanation( // 不重新请求模型
            text: payload.explanationText ?? "",
            alignment: payload.explanationAlignment
        )
        if AppSettings.shared.explanationTargetLanguage != language {
            AppSettings.shared.explanationTargetLanguage = language // 记住下次打开看这一种
        }
    }

    /// 清掉当前显示语言的讲解。其它语言不动。调用前屏幕上的讲解应已清空。
    func discardDisplayed() {
        let id = displayed.rawValue
        guard AIBookBundle.isLanguageID(id) else { return }
        document.bundledExplanationLanguageID = id // 快照只清这一栏
        document.snapshotActiveBundledLanguages() // 空正文会拿掉讲解
    }
}

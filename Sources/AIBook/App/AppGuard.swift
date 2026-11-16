import AppKit
import Foundation

/// 跨模块的入口拦截：读书 LLM / 进化桥没配好、未保存确认、覆盖确认。不发起请求。
@MainActor
enum AppGuard {
    /// 读书侧 LLM 没配好时的错误文案；配好了返回 nil。
    static func bookLLMErrorMessage(for settings: AppSettings) -> String? {
        if settings.isBookLLMConfigured { return nil } // 已能发讲解/翻译
        return BookL10n.format("guard.apiKey", settings.bookProvider.rawValue) // 提示补当前提供商的 key
    }

    /// 丢弃未保存改动的确认框。第一按钮才算确认。
    static func confirmDiscardUnsavedChanges() -> Bool {
        let alert = NSAlert()
        alert.messageText = BookL10n.string("alert.discard.title")
        alert.informativeText = BookL10n.string("alert.discard.message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: BookL10n.string("alert.discard.confirm")) // 第一按钮 = 丢弃
        alert.addButton(withTitle: BookL10n.string("alert.cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// 目标文件已存在时的覆盖确认。
    static func confirmOverwriteExistingFile(at url: URL) -> Bool {
        let alert = NSAlert()
        alert.messageText = BookL10n.string("alert.overwrite.title")
        alert.informativeText = BookL10n.format("alert.overwrite.message", url.lastPathComponent) // 带文件名，避免盖错
        alert.alertStyle = .warning
        alert.addButton(withTitle: BookL10n.string("alert.overwrite.confirm"))
        alert.addButton(withTitle: BookL10n.string("alert.cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }
}

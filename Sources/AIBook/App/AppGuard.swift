import AppKit
import Foundation

/// 跨模块的入口拦截：读书 LLM / 进化桥没配好、未保存确认、覆盖确认。不发起请求。
@MainActor
enum AppGuard {
    /// 读书侧 LLM 没配好时的错误文案；配好了返回 nil。
    static func bookLLMErrorMessage(for settings: AppSettings) -> String? {
        if settings.isBookLLMConfigured { return nil } // 已能发讲解/翻译
        if settings.bookProvider == .ollama {
            return BookL10n.string("guard.ollama") // 本地模型单独一句，不提 API Key
        }
        return BookL10n.format("guard.apiKey", settings.bookProvider.rawValue) // 云厂商提示补 key
    }

    /// 进化通道不可用时的错误文案。Cursor 能跑则放行。
    static func evolutionSourceErrorMessage(for settings: AppSettings) -> String? {
        if settings.isCursorRunnable { return nil }
        if !settings.isCursorBridgeReady {
            return settings.cursorBridgeStatusMessage // 桥路径/进程的具体原因，比泛文案有用
        }
        return BookL10n.string("guard.cursorEvolution") // 桥好了但还不能跑（例如缺 key）
    }

    /// 讲解入口以前和进化共用后端，现在仍走同一套 Cursor 检查，避免两套标准。
    static func explanationSourceErrorMessage(for settings: AppSettings) -> String? {
        evolutionSourceErrorMessage(for: settings) // 有意复用，改进化检查时讲解一起变
    }

    /// 自进化必须走 Cursor 本地桥，与 evolutionSource 同一条件。
    static func evolutionErrorMessage(for settings: AppSettings) -> String? {
        evolutionSourceErrorMessage(for: settings)
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

/// 进化服务没配好时抛给 UI 的本地化错误。
enum EvolutionServiceError: LocalizedError {
    case notConfigured(String) // 关联值为已经本地化好的句子，这里不再包一层目录

    var errorDescription: String? {
        switch self {
        case .notConfigured(let message):
            return message // 原样交给 alert
        }
    }
}

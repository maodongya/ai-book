import AppKit
import Foundation

/// Cross-cutting guards for explanation source validation and unsaved edits.
@MainActor
enum AppGuard {
    static func bookLLMErrorMessage(for settings: AppSettings) -> String? {
        if settings.isBookLLMConfigured { return nil }
        if settings.bookProvider == .ollama {
            return "请确认 Ollama 已启动（终端执行 ollama serve），并在 book 设置中刷新并选择本地模型。"
        }
        return "请先在 book 设置中为「\(settings.bookProvider.rawValue)」配置 API Key。"
    }

    static func evolutionSourceErrorMessage(for settings: AppSettings) -> String? {
        switch settings.explanationSource {
        case .cursor:
            if settings.isCursorRunnable || settings.isLLMConfigured {
                return nil
            }
            if !settings.isCursorBridgeReady {
                return settings.cursorBridgeStatusMessage
            }
            return "请配置进化用大模型 API，或填写 Cursor API Key 并确保 cursor-bridge 已安装（npm install）。"
        case .llm:
            if settings.isLLMConfigured { return nil }
            if settings.provider == .ollama {
                return "请确认 Ollama 已启动，并在 AI 进化 Tab 的模型设置中选择本地模型。"
            }
            return "请先在 AI 进化 Tab 为「\(settings.provider.rawValue)」配置 API Key。"
        }
    }

    /// Reading + evolution entry points that previously shared one backend.
    static func explanationSourceErrorMessage(for settings: AppSettings) -> String? {
        evolutionSourceErrorMessage(for: settings)
    }

    /// Self-evolution prefers Cursor local bridge; falls back to LLM when bridge is unavailable.
    static func evolutionErrorMessage(for settings: AppSettings) -> String? {
        if settings.isCursorRunnable || settings.isLLMConfigured {
            return nil
        }
        return "请配置大模型 API，或填写 Cursor API Key 以使用本地进化。"
    }

    static func confirmDiscardUnsavedChanges() -> Bool {
        let alert = NSAlert()
        alert.messageText = "有未保存的修改"
        alert.informativeText = "是否放弃当前修改并继续？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "放弃修改")
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func confirmOverwriteExistingFile(at url: URL) -> Bool {
        let alert = NSAlert()
        alert.messageText = "文件已存在"
        alert.informativeText = "「\(url.lastPathComponent)」已存在，是否覆盖？"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "覆盖")
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }
}

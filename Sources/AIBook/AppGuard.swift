import AppKit
import Foundation

/// Cross-cutting guards for explanation source validation and unsaved edits.
@MainActor
enum AppGuard {
    static func explanationSourceErrorMessage(for settings: AppSettings) -> String? {
        switch settings.explanationSource {
        case .cursor:
            if settings.isCursorRunnable || settings.isLLMConfigured {
                return nil
            }
            if !settings.isCursorBridgeReady {
                return settings.cursorBridgeStatusMessage
            }
            return "请配置大模型 API，或填写 Cursor API Key 并确保 cursor-bridge 已安装（npm install）。"
        case .llm:
            if settings.isLLMConfigured { return nil }
            if settings.provider == .ollama {
                return "请确认 Ollama 已启动（终端执行 ollama serve），并在设置 → Ollama 中刷新并选择本地模型。"
            }
            return "请先在设置或右页为当前提供商「\(settings.provider.rawValue)」配置 API Key（切换提供商不会共用其他家的 Key）。"
        }
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

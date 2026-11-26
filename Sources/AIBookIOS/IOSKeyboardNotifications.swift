import Foundation

/// iPad 外接键盘快捷键对应的 Notification（由 App 层 post）。
extension Notification.Name {
    /// iPad 外接键盘：进入阅读。
    static let iosShortcutEnterReading = Notification.Name("ios.shortcut.enterReading") // ⌘⇧R
    /// 停止朗读或模型请求。
    static let iosShortcutStop = Notification.Name("ios.shortcut.stop") // ⌘.
}
import AppKit

/// 系统原生全屏开关。只 togglestyleMask，不自己画全屏窗。
enum WindowFullscreenHelper {
    /// 与当前状态不同才 toggle，避免重复动画。
    static func setNativeFullscreen(_ enabled: Bool) {
        guard let window = keyWindow else { return } // 没有前台窗就不动
        let isFullscreen = window.styleMask.contains(.fullScreen)
        guard enabled != isFullscreen else { return } // 已经是目标态
        window.toggleFullScreen(nil) // 走系统全屏，和绿钮一致
    }

    /// 当前 key/main/可见窗是否已是原生全屏。
    static var isNativeFullscreen: Bool {
        keyWindow?.styleMask.contains(.fullScreen) ?? false // 没窗当否
    }

    /// 找要操作的窗：key → main → 第一扇可见窗。
    private static var keyWindow: NSWindow? {
        NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first { $0.isVisible }
    }
}

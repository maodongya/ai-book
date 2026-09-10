import AppKit

enum WindowFullscreenHelper {
    static func setNativeFullscreen(_ enabled: Bool) {
        guard let window = keyWindow else { return }
        let isFullscreen = window.styleMask.contains(.fullScreen)
        guard enabled != isFullscreen else { return }
        window.toggleFullScreen(nil)
    }

    static var isNativeFullscreen: Bool {
        keyWindow?.styleMask.contains(.fullScreen) ?? false
    }

    private static var keyWindow: NSWindow? {
        NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first { $0.isVisible }
    }
}

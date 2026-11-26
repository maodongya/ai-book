import SwiftUI

/// iOS 入口。Mac 窗口仍由 AIBookApp 负责，这里不引用它。
@main
struct AIBookIOSApp: App {
    var body: some Scene {
        WindowGroup {
            IOSRootView() // 手机一次一页，宽屏再并排
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Button(BookL10n.string("mode.reading")) {
                    NotificationCenter.default.post(name: .iosShortcutEnterReading, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                Button(BookL10n.string("action.stop")) {
                    NotificationCenter.default.post(name: .iosShortcutStop, object: nil)
                }
                .keyboardShortcut(".", modifiers: .command)
            }
        }
    }
}

import AppKit

/// 应用代理：启动时激活窗口、退出前问未保存。不负责 SwiftUI 场景树。
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 给退出确认用的弱引用，由 AIBookApp.onAppear 挂上，避免和 Scene 抢所有权。
    weak var readingViewModel: ReadingViewModel?

    /// 启动完成：灌 Cursor 鉴权、变成普通 app、拉到前台、统一窗口标题。
    func applicationDidFinishLaunching(_ notification: Notification) {
        CursorAuthBootstrap.applyOnLaunch() // 启动时写入/刷新 Cursor 侧凭据
        NSApp.setActivationPolicy(.regular) // 保证有 Dock 和菜单，不当 accessory
        NSApp.activate(ignoringOtherApps: true) // 从终端 `swift run` 时也要跳到前台
        applyWindowTitle() // 标题随产品名和界面语言
    }

    /// 把所有已开窗口的标题设成当前语言下的产品标题。
    private func applyWindowTitle() {
        let title = AIBookProduct.windowTitle // 显示名 · 标语
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.title = title // 隐藏标题栏时仍给 Mission Control / 语音识别用
            }
        }
    }

    /// 有未保存文档则弹确认；取消则留下进程。
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let viewModel = readingViewModel, viewModel.document.isDirty else {
            return .terminateNow // 没挂上 VM 或没脏数据，直接退
        }
        return viewModel.document.confirmDiscardUnsavedIfNeeded() ? .terminateNow : .terminateCancel // 用户点取消则留下
    }

    /// 关最后一扇窗就退出，符合文档型 app。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

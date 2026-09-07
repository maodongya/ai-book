import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var readingViewModel: ReadingViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        CursorAuthBootstrap.applyOnLaunch()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        applyWindowTitle()
    }

    private func applyWindowTitle() {
        let title = AIBookProduct.windowTitle
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.title = title
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let viewModel = readingViewModel, viewModel.isDirty else {
            return .terminateNow
        }
        return viewModel.confirmDiscardUnsavedIfNeeded() ? .terminateNow : .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

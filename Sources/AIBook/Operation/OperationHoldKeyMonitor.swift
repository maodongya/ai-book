import AppKit
import Foundation

/// 前台按住 Option+空格。SwiftUI 的 keyboardShortcut 不能表达按住。
final class OperationHoldKeyMonitor {
    var onDown: () -> Void = {} // 开始听
    var onUp: () -> Void = {} // 松开后解析
    private var monitor: Any? // 本地监视，离开时拆掉
    private var holding = false // 避免重复 keyDown

    /// 只在本应用前台收按键。
    func start() {
        guard monitor == nil else { return } // 已经装过
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            let isOptionSpace = event.keyCode == 49 && event.modifierFlags.contains(.option) // 空格键码 49
            guard isOptionSpace else { return event } // 其它键照常
            if event.type == .keyDown, !event.isARepeat, !self.holding {
                self.holding = true
                self.onDown()
            } else if event.type == .keyUp, self.holding {
                self.holding = false
                self.onUp()
            }
            return nil // 按住说话时不把空格打进文本
        }
    }

    /// 窗口关闭时拆监视。
    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        holding = false
    }
}

import AppKit
import SwiftUI

/// 顶栏按住说话。松开后交给 OperationAssistantModel。
struct OperationMicButton: View {
    @ObservedObject var model: OperationAssistantModel
    @ObservedObject private var localizationSettings = AppSettings.shared  // 语言变了重画麦克风提示

    var body: some View {
        let _ = localizationSettings.localizationRevision  // 界面语言变了重取文案
        Image(systemName: model.isListening ? "mic.fill" : "mic") // 听的时候实心
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(model.isListening ? BookTheme.ink : BookTheme.goldSoft)
            .frame(width: 36, height: 36)
            .background {
                Circle()
                    .fill(model.isListening ? BookTheme.goldSoft : Color.white.opacity(0.14))
                Circle()
                    .strokeBorder(BookTheme.goldSoft, lineWidth: model.isListening ? 3 : 1.2)
            }
            .scaleEffect(model.isListening ? 1.12 : 1)
            .animation(.easeOut(duration: 0.15), value: model.isListening)
            .overlay {
                OperationPressHoldView(onDown: { model.beginHold() }, onUp: { // 鼠标不移动也会收到松开
                    Task { await model.endHold() }
                })
                .frame(width: 36, height: 36) // 命中层和圆一样大
            }
            .help(BookL10n.string("operation.mic.help"))
    }
}

/// 按下开始、松开结束。不依赖拖动手势，零位移时拖动手势收不到松开。
struct OperationPressHoldView: NSViewRepresentable {
    var onDown: () -> Void
    var onUp: () -> Void

    func makeNSView(context: Context) -> OperationPressHoldNSView {
        let view = OperationPressHoldNSView()
        view.onDown = onDown
        view.onUp = onUp
        return view
    }

    func updateNSView(_ nsView: OperationPressHoldNSView, context: Context) {
        nsView.onDown = onDown // 视图刷新后仍指向当前模型
        nsView.onUp = onUp
    }
}

/// 透明命中层。松开即使离开按钮也结束这一句。
final class OperationPressHoldNSView: NSView {
    var onDown: () -> Void = {}
    var onUp: () -> Void = {}
    private var monitors: [Any] = [] // 按下后才装，松开就拆
    private var awaitingUp = false // 本地和全局监视只结束一次

    override var isOpaque: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true } // 窗口未激活时第一下也算

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil // 透明层也要接到按下
    }

    override func mouseDown(with event: NSEvent) {
        onDown()
        awaitingUp = true
        removeMonitors()
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp], handler: { [weak self] event in
            self?.finish() // 在窗口内松开
            return event
        }) {
            monitors.append(local)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp], handler: { [weak self] _ in
            DispatchQueue.main.async {
                self?.finish() // 全局监视不在主线程，视图更新必须回去
            }
        }) {
            monitors.append(global)
        }
    }

    override func mouseUp(with event: NSEvent) {
        finish() // 按下的这个视图会收到松开，即使指针没移动
    }

    /// 一次松开只回调一次。
    private func finish() {
        guard awaitingUp else { return }
        awaitingUp = false
        removeMonitors()
        onUp()
    }

    private func removeMonitors() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
    }

    deinit {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor) // 视图消失时不能留下监视
        }
    }
}

/// 听到的话和正在做的操作。成功失败都不另开窗口。
struct OperationStatusLine: View {
    @ObservedObject var model: OperationAssistantModel
    @ObservedObject private var localizationSettings = AppSettings.shared  // 语言变了重画状态条

    var body: some View {
        let _ = localizationSettings.localizationRevision  // 界面语言变了重取文案
        if model.showsStatus {
            HStack(spacing: 8) {
                if model.isListening {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
                Text(model.statusText)
                    .font(BookTheme.captionFont.weight(.semibold))
                    .foregroundStyle(model.isListening ? BookTheme.ink : Color.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    model.dismissStatus() // 理解中走停止，空闲时只收起
                } label: {
                    Image(systemName: model.isBusy ? "stop.fill" : "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(model.isListening ? BookTheme.ink : Color.white)
                }
                .buttonStyle(.plain)
                .help(BookL10n.string("operation.status.dismiss"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Capsule()
                    .fill(model.isListening ? BookTheme.goldSoft : Color.black.opacity(0.78))
            }
        }
    }
}

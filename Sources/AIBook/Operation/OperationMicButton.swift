import SwiftUI

/// 顶栏按住说话。松开后交给 OperationAssistantModel。
struct OperationMicButton: View {
    @ObservedObject var model: OperationAssistantModel

    var body: some View {
        Image(systemName: model.isListening ? "mic.fill" : "mic") // 听的时候实心
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(model.isListening ? BookTheme.goldSoft : Color.white.opacity(0.82))
            .frame(width: 28, height: 28)
            .background {
                Circle()
                    .fill(Color.white.opacity(model.isListening ? 0.2 : 0.08))
            }
            .help(BookL10n.string("operation.mic.help"))
            .onLongPressGesture(minimumDuration: 0, maximumDistance: 48, pressing: { pressing in
                if pressing {
                    model.beginHold() // 按下开始听
                } else {
                    Task { await model.endHold() } // 松开再解析
                }
            }, perform: {})
    }
}

/// 听到的话和正在做的操作。成功失败都不另开窗口。
struct OperationStatusLine: View {
    @ObservedObject var model: OperationAssistantModel

    var body: some View {
        if model.showsStatus {
            HStack(spacing: 8) {
                Text(model.statusText)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.goldSoft)
                    .lineLimit(2)
                Button {
                    model.dismissStatus()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help(BookL10n.string("operation.status.dismiss"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
    }
}

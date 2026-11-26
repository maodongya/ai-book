import SwiftUI

/// 按住麦克风说口令。命令栏形态不拉高顶栏，听写提示走整行文案。
enum IOSMicPresentation {
    case commandBar
    case readingChrome
}

struct IOSMicButton: View {
    @ObservedObject var voice: IOSVoiceController
    var presentation: IOSMicPresentation = .readingChrome

    var body: some View {
        switch presentation {
        case .commandBar:
            micIcon
        case .readingChrome:
            VStack(alignment: .trailing, spacing: 4) {
                micIcon
                if voice.holding || !voice.heard.isEmpty {
                    Text(voice.holding ? BookL10n.string("operation.listening") : voice.heard)
                        .font(.caption)
                        .foregroundStyle(IOSPaper.ink)
                        .lineLimit(2)
                }
            }
        }
    }

    private var micIcon: some View {
        Image(systemName: voice.holding ? "mic.fill" : "mic")
            .font(.title3)
            .foregroundStyle(IOSPaper.ink)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !voice.holding { voice.beginHold() }
                    }
                    .onEnded { _ in voice.endHold() }
            )
            .accessibilityLabel(BookL10n.string("operation.mic.help"))
    }
}
import SwiftUI

/// 非阅读页顶栏：右侧统一菜单与麦克风，独占一行不压正文。
struct IOSTopCommandBar: View {
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var document: IOSDocument
    @ObservedObject var settings: IOSModelSettings
    @ObservedObject var service: IOSReadingService
    @ObservedObject var speaker: IOSSpeaker
    @ObservedObject var voice: IOSVoiceController
    @Binding var showManual: Bool
    @Binding var showPrivacy: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Spacer(minLength: 0)
                IOSUnifiedTopMenu(
                    shell: shell,
                    document: document,
                    settings: settings,
                    service: service,
                    speaker: speaker,
                    showManual: $showManual,
                    showPrivacy: $showPrivacy
                )
                IOSMicButton(voice: voice, presentation: .commandBar)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            if voice.holding || !voice.heard.isEmpty {
                Text(voice.holding ? BookL10n.string("operation.listening") : voice.heard)
                    .font(.caption)
                    .foregroundStyle(IOSPaper.inkMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .iosPanelChrome(edge: .bottom)
    }
}
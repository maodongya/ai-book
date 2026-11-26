import SwiftUI

/// iPad 宽屏右半：讲解与翻译分段切换，左半原文不动。
struct IOSSplitAssistantPane<Translation: View, Explanation: View>: View {
    @ObservedObject var shell: IOSShellModel
    let translation: () -> Translation
    let explanation: () -> Explanation

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: Binding(
                get: { shell.page == .translation ? IOSPage.translation : IOSPage.explanation },
                set: { shell.select($0) }
            )) {
                Text(BookL10n.string("target.explanation")).tag(IOSPage.explanation)
                Text(BookL10n.string("target.translation")).tag(IOSPage.translation)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Group {
                if shell.page == .translation {
                    translation()
                } else {
                    explanation()
                }
            }
        }
    }
}
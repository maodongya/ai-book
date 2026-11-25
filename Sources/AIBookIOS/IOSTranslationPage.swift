import SwiftUI

/// 翻译页。结构和讲解页对称：空状态是逐字和整段，有译文后正文可改。
struct IOSTranslationPage: View {
    @ObservedObject var document: IOSDocument
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var settings: IOSModelSettings
    @ObservedObject var service: IOSReadingService
    @ObservedObject var speaker: IOSSpeaker
    var showsPageMenu = true
    @State private var comparing = false

    var body: some View {
        VStack(spacing: 0) {
            IOSPageHeading(titleKey: "target.translation", shell: shell, showsPageMenu: showsPageMenu) {
                IOSTranslationMenu(document: document, shell: shell, settings: settings, service: service, speaker: speaker)
            }
            if document.translation.isEmpty {
                empty // 还没有译文，不显示语言分段
            } else {
                if document.translationLanguageIDs.count > 1 {
                    Picker("", selection: Binding(
                        get: { document.activeLanguageID },
                        set: { document.selectLanguage($0) }
                    )) {
                        ForEach(document.translationLanguageIDs, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                Button(BookL10n.string("translation.tableCompare")) { comparing.toggle() } // 对照留在页顶
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                if comparing {
                    IOSCompareList(pairs: IOSParagraphPairs.pairs(source: document.source, other: document.translation))
                } else {
                    TextEditor(text: Binding(
                        get: { document.translation },
                        set: { document.storeTranslation($0) } // 改字写回当前语言
                    ))
                    .foregroundStyle(IOSPaper.ink)
                    .scrollContentBackground(.hidden)
                    .padding(20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IOSPaper.page)
    }

    /// 源文本优先选区，没有选区就用全文。模型没配好则去设置。
    private var empty: some View {
        VStack(spacing: 16) {
            Spacer()
            Button(BookL10n.string("action.wordTranslation")) {
                begin(paragraph: false) // 逐字
            }
            .disabled(settings.isReady && !document.hasSource)
            Button(BookL10n.string("action.paragraphTranslation")) {
                begin(paragraph: true) // 整段
            }
            .disabled(settings.isReady && !document.hasSource)
            if service.running {
                Button(BookL10n.string("action.stop")) { service.cancel() }
            }
            if !service.status.isEmpty {
                Text(service.status) // 正在翻译或失败原因
                    .font(.footnote)
                    .foregroundStyle(IOSPaper.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .buttonStyle(.borderedProminent)
    }

    /// 没配模型就离开本页去设置，配好了就按选区或全文翻译。
    private func begin(paragraph: Bool) {
        if !settings.isReady {
            shell.select(.settings) // 不先发失败请求
            return
        }
        service.translate(document: document, settings: settings, paragraph: paragraph)
    }
}

import SwiftUI

/// 翻译页。结构和讲解页对称：空状态是逐字和整段，有译文后正文可改。
struct IOSTranslationPage: View {
    @ObservedObject var document: IOSDocument
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var settings: IOSModelSettings
    @ObservedObject var service: IOSReadingService
    @ObservedObject var speaker: IOSSpeaker
    var showsPageMenu = false
    @State private var comparing = false

    private var compareData: (pairs: [(source: String, other: String)], usesAlignment: Bool) {
        IOSParagraphPairs.pairs(
            source: document.source,
            other: document.translation,
            alignment: document.translationAlignment
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            IOSPageHeading(titleKey: "target.translation")
            if document.translation.isEmpty {
                empty // 还没有译文，不显示语言分段
            } else {
                if document.translationLanguageIDs.count > 1 {
                    Picker("", selection: Binding(
                        get: { document.activeLanguageID },
                        set: { document.selectLanguage($0) }
                    )) {
                        ForEach(document.translationLanguageIDs, id: \.self) { id in
                            Text(IOSLanguageLabels.displayName(for: id)).tag(id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                Button {
                    comparing.toggle() // 对照留在页顶
                } label: {
                    Label(BookL10n.string("translation.tableCompare"), systemImage: comparing ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(IOSPaper.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                if comparing, document.translationAlignment?.isStale == true {
                    Text(BookL10n.string("vm.align.stale"))
                        .font(.footnote)
                        .foregroundStyle(IOSPaper.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                }
                if comparing {
                    IOSCompareList(
                        pairs: compareData.pairs,
                        highlightedPairIndex: IOSParagraphPairs.highlightedPairIndex(
                            pairs: compareData.pairs,
                            source: document.source,
                            selection: document.selection,
                            characterAnchor: document.readingCharacterAnchor,
                            alignment: document.translationAlignment
                        ),
                        otherColumnTitleKey: "target.translation",
                        editableOther: true,
                        onSelectSource: { index in
                            document.selectSourcePair(at: index, in: compareData.pairs)
                            shell.select(.source)
                        },
                        onEditOther: { index, text in
                            document.updateCompanionPair(
                                at: index,
                                pairs: compareData.pairs,
                                newOther: text,
                                explanation: false
                            )
                        }
                    )
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
        #if DEBUG
        .onAppear {
            if IOSSnapshotHints.translationCompare { comparing = true }
        }
        #endif
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

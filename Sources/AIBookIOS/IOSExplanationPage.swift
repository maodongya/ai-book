import SwiftUI

/// 讲解页。没有讲解时只留两枚按钮；有了之后上半是正文，下半是追问。
struct IOSExplanationPage: View {
    @ObservedObject var document: IOSDocument
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var settings: IOSModelSettings
    @ObservedObject var service: IOSReadingService
    @ObservedObject var speaker: IOSSpeaker
    var showsPageMenu = true
    @State private var followUp = ""
    @State private var comparing = false

    var body: some View {
        VStack(spacing: 0) {
            IOSPageHeading(titleKey: "target.explanation", shell: shell, showsPageMenu: showsPageMenu) {
                IOSExplanationMenu(document: document, shell: shell, settings: settings, service: service, speaker: speaker)
            }
            if !service.status.isEmpty {
                Text(service.status) // 正在讲解或失败原因
                    .font(.footnote)
                    .foregroundStyle(IOSPaper.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
            }
            if document.explanation.isEmpty {
                empty // 还没生成，不显示语言分段
            } else {
                languageBar(document.explanationLanguageIDs)
                compareButton("explanation.tableCompare") // 对照留在页顶，不占页底
                if comparing {
                    IOSCompareList(pairs: IOSParagraphPairs.pairs(source: document.source, other: document.explanation))
                } else {
                    ScrollView {
                        Text(document.explanation)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(IOSPaper.ink)
                            .padding(24)
                    }
                }
            }
            followUpBar // 键盘弹起时贴在键盘上，由系统安全区处理
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IOSPaper.page)
    }

    /// 已生成的语言。只有一种时不占地方。
    private func languageBar(_ ids: [String]) -> some View {
        Group {
            if ids.count > 1 {
                Picker("", selection: Binding(
                    get: { document.activeLanguageID },
                    set: { document.selectLanguage($0) } // 切换只改显示
                )) {
                    ForEach(ids, id: \.self) { id in
                        Text(id).tag(id)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
    }

    /// 对照开关。放在正文上方，页底只留追问输入。
    private func compareButton(_ key: String) -> some View {
        Button(BookL10n.string(key)) { comparing.toggle() } // 上下叠放，不左右分栏
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
    }

    /// 空状态。模型没配好时按钮改去设置，不先发一次失败请求。
    private var empty: some View {
        VStack(spacing: 16) {
            Spacer()
            Button(BookL10n.string("action.explainSelection")) {
                openOrExplain(selectionOnly: true) // 没有选区时按钮不可用
            }
            .disabled(settings.isReady && document.selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(BookL10n.string("action.explainFull")) {
                openOrExplain(selectionOnly: false)
            }
            .disabled(settings.isReady && !document.hasSource)
            if service.running {
                Button(BookL10n.string("action.stop")) {
                    service.cancel() // 这一轮不再写回
                }
            }
            if !settings.isReady {
                Text(BookL10n.string("help.configureBookLLM")) // 先去设置，不发请求
                    .font(.footnote)
                    .foregroundStyle(IOSPaper.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else if document.selection.isEmpty {
                Text(BookL10n.string("welcome.hint2")) // 先回原文选中
                    .font(.footnote)
                    .foregroundStyle(IOSPaper.inkMuted)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .buttonStyle(.borderedProminent)
    }

    /// 追问输入。这一版只留下输入条，发送仍等模型接到 iOS。
    private var followUpBar: some View {
        HStack {
            TextField(BookL10n.string("placeholder.translation"), text: $followUp)
                .textFieldStyle(.roundedBorder)
            Button(BookL10n.string("action.send")) {
                service.explain(document: document, settings: settings, selectionOnly: false, followUp: followUp)
                followUp = "" // 发出去就清掉输入
            }
                .disabled(followUp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !settings.isReady || service.running)
        }
        .padding(12)
    }

    /// 模型未就绪就去设置；就绪时按选区或全文请求讲解。
    private func openOrExplain(selectionOnly: Bool) {
        if !settings.isReady {
            shell.select(.settings) // 设计要求先打开模型设置
            return
        }
        service.explain(document: document, settings: settings, selectionOnly: selectionOnly)
    }
}

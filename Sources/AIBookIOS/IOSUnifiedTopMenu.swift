import SwiftUI

/// 右上角统一菜单：换页、本页操作、全书设置。麦克风仍单独贴在右侧。
struct IOSUnifiedTopMenu: View {
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var document: IOSDocument
    @ObservedObject var settings: IOSModelSettings
    @ObservedObject var service: IOSReadingService
    @ObservedObject var speaker: IOSSpeaker
    @Binding var showManual: Bool
    @Binding var showPrivacy: Bool
    @State private var confirmNew = false

    var body: some View {
        Menu {
            Section(BookL10n.string("ios.menu.section.navigate")) {
                ForEach(IOSPage.bubbleOrder) { page in
                    Button {
                        shell.select(page) // 与底栏一致的换页入口
                    } label: {
                        if shell.page == page {
                            Label(BookL10n.string(page.titleKey), systemImage: "checkmark")
                        } else {
                            Text(BookL10n.string(page.titleKey))
                        }
                    }
                }
            }
            pageActionSection
            Section(BookL10n.string("ios.menu.section.book")) {
                IOSBookMenuItems(shell: shell, document: document, showManual: $showManual, showPrivacy: $showPrivacy)
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(IOSPaper.ink)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(BookL10n.string("help.panelOverflow"))
        .confirmationDialog(BookL10n.string("action.newSource"), isPresented: $confirmNew, titleVisibility: .visible) {
            Button(BookL10n.string("action.newSource"), role: .destructive) {
                document.newDocument() // 确认后才清掉未保存的原文
            }
            Button(BookL10n.string("alert.cancel"), role: .cancel) {}
        }
    }

    @ViewBuilder
    private var pageActionSection: some View {
        switch shell.page {
        case .source:
            Section(BookL10n.string("context.label.source")) {
                IOSDocumentMenuItems(
                    document: document,
                    shell: shell,
                    settings: settings,
                    service: service,
                    speaker: speaker,
                    confirmNew: $confirmNew
                )
            }
        case .explanation:
            Section(BookL10n.string("target.explanation")) {
                IOSExplanationMenuItems(
                    document: document,
                    shell: shell,
                    settings: settings,
                    service: service,
                    speaker: speaker
                )
            }
        case .translation:
            Section(BookL10n.string("target.translation")) {
                IOSTranslationMenuItems(
                    document: document,
                    shell: shell,
                    settings: settings,
                    service: service,
                    speaker: speaker
                )
            }
        case .settings, .reading:
            EmptyView() // 设置页本体内操作，阅读页无顶栏菜单
        }
    }
}
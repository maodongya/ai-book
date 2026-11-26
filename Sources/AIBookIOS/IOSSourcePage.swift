import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 原文页：打开、编辑、选区上的讲解翻译朗读。文档菜单在标题旁。
struct IOSSourcePage: View {
    @ObservedObject var document: IOSDocument
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var settings: IOSModelSettings
    @ObservedObject var service: IOSReadingService
    @ObservedObject var speaker: IOSSpeaker
    @ObservedObject private var styleManager = BookStyleManager.shared // 正文字号跟 Mac 偏好
    var showsPageMenu = false

    var body: some View {
        let _ = styleManager.revision // 切预设时编辑器墨色与字号一起变
        VStack(spacing: 0) {
            title // 文件名和未保存的小点
            if !document.hasSource {
                empty // 还没字时仍可打开文件，下面的编辑器也能直接打
            }
            if !service.status.isEmpty {
                Text(service.status) // 原文补充的进度或失败原因
                    .font(.footnote)
                    .foregroundStyle(IOSPaper.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
            editor // 空白页也能输入
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IOSPaper.page)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if !document.selection.isEmpty {
                    selectionBar
                }
                if shell.showsBubble {
                    sourceBottomBar
                }
            }
        }
    }

    /// 高频原文操作。短标签适配底栏，完整名仍在右上角菜单。
    private var sourceBottomBar: some View {
        IOSQuickActionBar {
            IOSQuickActionButton(titleKey: "ios.bar.saveSource", disabled: !document.hasSource) {
                document.exportKind = .text
            }
            IOSQuickActionButton(titleKey: "ios.bar.saveSourceAs", disabled: !document.hasSource) {
                document.exportKind = .saveAs
            }
            IOSQuickActionButton(titleKey: "ios.bar.supplement", disabled: !document.hasSource || service.running) {
                guard document.hasSource else { return }
                if settings.isReady {
                    service.supplement(document: document, settings: settings)
                } else {
                    shell.select(.settings)
                }
            }
            IOSQuickActionButton(titleKey: "ios.bar.selectAll", disabled: !document.hasSource) {
                document.selection = document.source
            }
        }
    }

    /// 当前文件名。没文件时用原文二字。
    private var title: some View {
        HStack(spacing: 8) {
            Text(document.title.isEmpty ? BookL10n.string("context.label.source") : document.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(IOSPaper.ink)
                .lineLimit(2)
            if document.dirty {
                Circle()
                    .fill(IOSPaper.inkMuted) // 未保存只在标题旁，不另做一页
                    .frame(width: 8, height: 8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, IOSLayout.pageTitleHorizontalPadding)
        .padding(.top, IOSLayout.pageTitleTopPadding)
    }
    /// 还没打开书时，打开文件仍留在编辑器上方。
    private var empty: some View {
        HStack(spacing: 12) {
            Button(BookL10n.string("welcome.openTextFile")) {
                document.libraryPresented = true // 先列出应用里的文本，取消能回来
            }
            .buttonStyle(.borderedProminent)
            Button(BookL10n.string("action.openDirectoryShort")) {
                document.importKind = .directory // 只选文件夹，和打开文件分开
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 12)
    }

    /// 可编辑正文。选中后才出现上面的三条。
    private var editor: some View {
        let typography = styleManager.tokens.typography
        return IOSSourceEditor(
            text: Binding(
                get: { document.source },
                set: { document.editSource($0) } // 改字就标未保存
            ),
            ink: UIColor(styleManager.tokens.colors.ink),
            bodyFont: typography.uiFont(size: typography.readingSize)
        ) { selected in
            document.selection = selected // 选区浮出讲解和翻译
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 空白时也占满，才能点进去打字
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    /// 选区条：与底栏快捷按钮同墨色描边样式。
    private var selectionBar: some View {
        IOSQuickActionBar {
            IOSQuickActionButton(titleKey: "action.explainSelection") {
                shell.select(.explanation) // 切到讲解页，选区留在 document 上
            }
            IOSQuickActionButton(titleKey: "target.translation") {
                shell.select(.translation) // 下一次翻译用这段选区
            }
            IOSQuickActionButton(titleKey: "action.readAloud") {
                speaker.speak(document.selection, contextTitleKey: "context.label.source")
            }
        }
    }
}

/// 系统导出用的字节。原文和 aibook 都走这一份。
struct IOSDataFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .data] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

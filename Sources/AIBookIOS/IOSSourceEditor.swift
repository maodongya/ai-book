import SwiftUI
import UIKit

/// 原文编辑器。选区变化交给页面，用来浮出讲解、翻译和朗读。
struct IOSSourceEditor: UIViewRepresentable {
    @Binding var text: String
    var ink: UIColor // 跟 BookStyle 令牌里的墨色
    var bodyFont: UIFont // 跟阅读正文字号
    var onSelection: (String) -> Void

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView() // 系统文本，才能拿到选区
        view.delegate = context.coordinator // 改字和改选区都从这里出来
        view.backgroundColor = .clear // 露出纸色
        view.font = bodyFont // 跟 Mac 阅读字号偏好
        view.textColor = ink // 与 IOSPaper.ink 同一墨色
        view.isEditable = true // 空白页也要能打字
        view.isSelectable = true
        view.alwaysBounceVertical = true
        view.text = text // 第一次把已打开的书放进去
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self // 绑定每次刷新都要指回当前页
        uiView.textColor = ink // 切预设时墨色一起变
        uiView.font = bodyFont // 切字号时编辑器一起变
        guard uiView.text != text else { return } // 正在打的字不要被替换掉
        uiView.text = text // 打开新文件或补充写回时才从外面灌入
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 320, height: max(proposal.height ?? 480, 200)) // 占满分到的纸面，空白处也能点
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self) // 代理要指回当前绑定
    }

    /// 把 UITextView 的选区和改字送回 SwiftUI。
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: IOSSourceEditor

        init(_ parent: IOSSourceEditor) {
            self.parent = parent // 持有绑定，才能写回 document
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text // 编辑即未保存
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard let range = textView.selectedTextRange else {
                parent.onSelection("") // 没有选区就收起浮条
                return
            }
            parent.onSelection(textView.text(in: range) ?? "") // 空选区是光标，浮条不出现
        }
    }
}

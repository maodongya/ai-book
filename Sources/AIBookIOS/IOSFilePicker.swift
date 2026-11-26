import SwiftUI
import UniformTypeIdentifiers

/// 自己弹出系统文件选择。取消和返回都会关掉，不再盖住正文。
struct IOSFilePicker: UIViewControllerRepresentable {
    @Binding var kind: IOSImportKind?
    var onPick: (URL, IOSImportKind) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear // 不画一层
        controller.view.isUserInteractionEnabled = false // 点击穿过，正文才能输入
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.parent = self // 绑定刷新后仍能关掉选择器
        context.coordinator.sync(controller) // 窗口还没好时会再试一次
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// 把系统选择器的结果送回 SwiftUI。
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: IOSFilePicker
        var presenting = false
        private var attempts = 0

        init(_ parent: IOSFilePicker) {
            self.parent = parent
        }

        /// 从当前窗口最上面的控制器弹出。取消时系统自己关掉。
        func sync(_ controller: UIViewController) {
            guard let kind = parent.kind else {
                presenting = false // 已经回到原文
                attempts = 0
                return
            }
            guard !presenting else { return } // 避免叠两个选择器
            guard controller.view.window != nil else {
                guard attempts < 8 else { return } // 窗口一直没有就停下
                attempts += 1
                DispatchQueue.main.async { [weak controller] in
                    guard let controller else { return }
                    self.sync(controller) // 等进了窗口再弹
                }
                return
            }
            attempts = 0
            presenting = true
            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: kind.contentTypes,
                asCopy: kind != .directory
            )
            picker.delegate = self // 选中和取消都走代理
            picker.allowsMultipleSelection = false
            if kind == .directory {
                if let bookmark = IOSDirectoryBookmark.resolve() {
                    picker.directoryURL = bookmark
                }
            } else {
                picker.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            }
            var host = controller.view.window?.rootViewController ?? controller
            while let next = host.presentedViewController {
                host = next // 已经有页面时叠在它上面
            }
            host.present(picker, animated: true)
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            presenting = false
            let kind = parent.kind
            parent.kind = nil // 先关掉，避免选择器留在屏幕上
            if let kind, let url = urls.first {
                parent.onPick(url, kind)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            presenting = false
            parent.kind = nil // 点取消或返回都回到原文
        }
    }
}

extension IOSImportKind {
    /// 打开文件只认文本和 aibook。打开目录只认文件夹。
    var contentTypes: [UTType] {
        switch self {
        case .directory:
            return [.folder]
        case .book, .explanation, .translation:
            return [.plainText, .utf8PlainText, .text, .data]
        }
    }
}

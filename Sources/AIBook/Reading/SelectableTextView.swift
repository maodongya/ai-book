import AppKit
import SwiftUI

/// 不抢 first responder，IME 才能落在里面的 TextView。
private final class ReadingScrollView: NSScrollView {
    /// 滚动条不抢焦点；正文要能编辑和 IME。
    override var acceptsFirstResponder: Bool { false }  // 滚动条不抢焦点
}

/// 禁拖放改文件，保留选区和 IME。
private final class ReadingTextView: NSTextView {
    /// 滚动条不抢焦点；正文要能编辑和 IME。
    override var acceptsFirstResponder: Bool { true }  // 正文要能编辑和 IME

    /// 指定 container 建视图，避开默认 TextKit 栈。
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)  // 走指定 container，不用默认那套
    }

    /// IB 路径。运行时走代码 init。
    required init?(coder: NSCoder) {
        super.init(coder: coder)  // IB 路径，实际用代码建
    }

    /// 进编辑时通知协调器。
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()  // 先问系统
        if became {  // 成功才钉死焦点
            window?.makeFirstResponder(self)  // 防止 ScrollView 再抢
        }
        return became  // 失败原样回
    }
}

/// 配置 inset 和滚动。
private func makeReadingTextView() -> ReadingTextView {
    let textStorage = NSTextStorage()  // 自己组 TextKit，避免默认 container 抢宽
    let layoutManager = NSLayoutManager()  // 排版
    textStorage.addLayoutManager(layoutManager)  // 绑上
    let textContainer = NSTextContainer(size: NSSize(  // 宽跟踪、高无限
        width: 0,  // make 后再跟 TextView 宽
        height: CGFloat.greatestFiniteMagnitude  // 只竖向滚
    ))
    textContainer.widthTracksTextView = true  // 换行跟视图宽
    textContainer.lineFragmentPadding = 0  // 左右 inset 用 textContainerInset
    layoutManager.addTextContainer(textContainer)  // 一套三件
    let textView = ReadingTextView(frame: .zero, textContainer: textContainer)  // 用我们禁拖放的子类
    textView.isRichText = false  // 纯文本，粘贴不带样式
    return textView  // 给 scroll 当 documentView
}

/// 左页可选正文。绑定更新时避开 IME 组字。
struct SelectableTextView: NSViewRepresentable {
    /// 纸色/墨色/字体，随主题换。
    enum Appearance {
        case reading  // 左页阅读
        case editor  // 目前和 reading 同一套字体

        /// 桥到 NSTextView 的正文字体。
        var font: NSFont {
            switch self {
            case .reading, .editor: return BookTheme.readingFont  // 本书设置的正文字体
            }
        }

        /// 桥到 NSTextView 的页边距。
        var textContainerInset: NSSize {
            return NSSize(width: 36, height: 32)  // 页边，和纸页视觉对齐
        }

        /// 桥到 NSTextView 的行距。
        var lineSpacing: CGFloat {
            switch self {
            case .reading, .editor: return BookTheme.readingLineSpacing  // 行距跟主题
            }
        }

        /// 桥到 NSTextView 的段距。
        var paragraphSpacing: CGFloat {
            switch self {
            case .reading, .editor: return 14  // 段距固定，和主题行距分开
            }
        }
    }

    @Binding var text: String  // 回写 VM
    var onSelectionChange: (String, NSRange?) -> Void  // 选区回 VM
    var onVisibleRangeChange: ((NSRange, CGFloat) -> Void)? = nil  // 给翻译对滚
    var scrollProxy: SelectableTextViewProxy? = nil  // 外部滚/高亮
    var appearance: Appearance = .reading  // 当前外观
    var isEditable: Bool = true  // 阅读模式可关编辑
    var selectAllSignal: UUID?  // 变了就全选一次

    /// 选区/IME/可见范围。
    func makeCoordinator() -> Coordinator {
        Coordinator(  // 把绑定和回调交给它
            text: $text,
            onSelectionChange: onSelectionChange,
            onVisibleRangeChange: onVisibleRangeChange,
            scrollProxy: scrollProxy
        )
    }

    /// ScrollView 包 TextView。
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = ReadingScrollView()  // 不抢焦点
        let textView = makeReadingTextView()  // 自己的 TextKit

        scrollView.drawsBackground = false  // 透出纸色
        scrollView.borderType = .noBorder  // 无边框
        scrollView.hasVerticalScroller = true  // 竖向
        scrollView.autohidesScrollers = true  // 不占宽

        textView.minSize = NSSize(width: 0, height: 0)  // 可以比视口小
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)  // 高随文长
        textView.isVerticallyResizable = true  // 竖向长
        textView.isHorizontallyResizable = false  // 不横滚
        textView.autoresizingMask = [.width]  // 跟 scroll 宽
        textView.textContainer?.widthTracksTextView = true  // 再钉一次
        textView.textContainer?.size = NSSize(  // 高无限
            width: 0,  // make 后再跟 TextView 宽
            height: CGFloat.greatestFiniteMagnitude  // 只竖向滚
        )

        textView.isEditable = isEditable  // 模式可能变了
        textView.isSelectable = true  // 关编辑仍能选/读
        textView.allowsUndo = true  // 编辑可撤
        textView.isAutomaticQuoteSubstitutionEnabled = false  // 别把引号换成弯引号
        textView.isAutomaticDashSubstitutionEnabled = false  // 别换破折号
        textView.isAutomaticTextReplacementEnabled = false  // 别自动改字
        textView.drawsBackground = false  // 透纸色
        applyAppearance(to: textView)  // 主题可能变了

        textView.isEditable = isEditable  // 模式可能变了

        textView.delegate = context.coordinator  // 改字/选区
        textView.string = text  // 灌新文

        scrollView.documentView = textView  // 装进去

        NotificationCenter.default.addObserver(  // 选区通知，delegate 的 selection 有时不够
            context.coordinator,  // 协调器收
            selector: #selector(Coordinator.selectionDidChange(_:)),  // 回 VM
            name: NSTextView.didChangeSelectionNotification,  // 选区变
            object: textView  // 只听这个
        )

        context.coordinator.textView = textView  // 后头全选/可见范围用
        context.coordinator.scrollView = scrollView  // 取 bounds.y
        context.coordinator.appearance = appearance  // 记住
        scrollView.contentView.postsBoundsChangedNotifications = true  // 否则滚了没通知
        NotificationCenter.default.addObserver(  // 选区通知，delegate 的 selection 有时不够
            context.coordinator,  // 协调器收
            selector: #selector(Coordinator.boundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,  // 拖滚动条
            object: scrollView.contentView  // clip view
        )
        NotificationCenter.default.addObserver(  // 选区通知，delegate 的 selection 有时不够
            context.coordinator,  // 协调器收
            selector: #selector(Coordinator.boundsDidChange(_:)),
            name: NSScrollView.didLiveScrollNotification,  // 手势滚动
            object: scrollView  // 整份 scroll
        )
        scrollProxy?.attach(textView: textView, scrollView: scrollView)  // 代理可能换
        DispatchQueue.main.async { [weak coordinator = context.coordinator] in  // 布局完再报可见范围
            coordinator?.emitVisibleRange()  // 对滚
        }
        return scrollView  // representable 根
    }

    /// 纸色墨色字体，不改选区。
    private func applyAppearance(to textView: NSTextView) {
        textView.font = appearance.font  // 正文字体
        textView.textColor = NSColor(BookTheme.ink)  // 墨色
        textView.insertionPointColor = NSColor(BookTheme.leather)  // 光标皮色
        textView.selectedTextAttributes = [  // 选区不要系统蓝
            .backgroundColor: NSColor(BookTheme.selection),  // 主题选区底
            .foregroundColor: NSColor(BookTheme.ink),  // 字仍是墨
        ]
        textView.textContainerInset = appearance.textContainerInset  // 页边
        textView.textContainer?.lineFragmentPadding = 0  // 避免和 inset 叠

        let paragraphStyle = NSMutableParagraphStyle()  // 行距段距
        paragraphStyle.lineSpacing = appearance.lineSpacing  // 主题
        paragraphStyle.paragraphSpacing = appearance.paragraphSpacing  // 14
        textView.defaultParagraphStyle = paragraphStyle  // 已有文字
        var typing = textView.typingAttributes  // 新打的也走这套
        typing[.font] = appearance.font  // 字体
        typing[.foregroundColor] = NSColor(BookTheme.ink)  // 墨
        typing[.paragraphStyle] = paragraphStyle  // 行距
        textView.typingAttributes = typing  // 写入
    }

    /// IME 组字时不覆盖 string。
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }  // 被拆过就停
        let coordinator = context.coordinator  // 状态在这

        textView.isEditable = isEditable  // 模式可能变了
        applyAppearance(to: textView)  // 主题可能变了
        coordinator.appearance = appearance  // 同步
        coordinator.onVisibleRangeChange = onVisibleRangeChange  // 回调可能换
        scrollProxy?.attach(textView: textView, scrollView: scrollView)  // 代理可能换

        if coordinator.lastSelectAllSignal != selectAllSignal, selectAllSignal != nil {  // 新信号
            coordinator.lastSelectAllSignal = selectAllSignal  // 只全选一次
            coordinator.selectAll()  // 并回 VM
        }

        if coordinator.isUpdatingFromView || coordinator.isComposingText || textView.hasMarkedText() { return } // 正在输入法组字时不要用绑定覆盖，否则会吞拼音
        guard textView.string != text else { return }  // 没变不灌，保光标

        scrollProxy?.clearHighlight()  // 正文换了旧高亮作废
        coordinator.isUpdatingFromBinding = true  // 别当作用户输入回写
        defer { coordinator.isUpdatingFromBinding = false }  // 出口清

        let selectedRange = textView.selectedRange()  // 尽量保住光标
        textView.string = text  // 灌新文
        let length = (text as NSString).length  // UTF-16
        let location = min(selectedRange.location, length)  // 夹进新长度
        let selectionLength = min(selectedRange.length, length - location)  // 选区也夹
        textView.setSelectedRange(NSRange(location: location, length: selectionLength))  // 恢复
        DispatchQueue.main.async { [weak coordinator] in  // 排完再报可见
            coordinator?.emitVisibleRange()  // 对滚
        }
    }

    /// 卸代理，避免野指针。
    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)  // 选区和滚动都卸
        coordinator.scrollProxy?.clearHighlight()  // 高亮层卸掉
        coordinator.textView = nil  // 防野指针
        coordinator.scrollView = nil  // 同上
    }

    /// 选区、IME、全选信号。isUpdatingFromBinding 防回环。
    final class Coordinator: NSObject, NSTextViewDelegate {
        var textView: NSTextView?  // documentView
        var scrollView: NSScrollView?  // 取偏移
        var appearance: Appearance = .reading  // 当前外观
        var lastSelectAllSignal: UUID?  // 上次已处理的信号
        @Binding var text: String  // 回写 VM
        let onSelectionChange: (String, NSRange?) -> Void  // 选区
        var onVisibleRangeChange: ((NSRange, CGFloat) -> Void)?  // 可见范围
        weak var scrollProxy: SelectableTextViewProxy?  // 弱，避免环

        /// textDidChange 正在把 NSTextView 写回绑定，避免再灌回去。
        var isUpdatingFromView = false
        /// updateNSView 正在灌外部绑定，别当作用户输入。
        var isUpdatingFromBinding = false
        /// IME 组字中，不要用绑定覆盖 marked text。
        var isComposingText = false

        /// 绑正文、选区回调和滚动代理。
        init(
            text: Binding<String>,
            onSelectionChange: @escaping (String, NSRange?) -> Void,
            onVisibleRangeChange: ((NSRange, CGFloat) -> Void)?,
            scrollProxy: SelectableTextViewProxy?
        ) {
            _text = text  // 绑定
            self.onSelectionChange = onSelectionChange  // 选区
            self.onVisibleRangeChange = onVisibleRangeChange  // 可见
            self.scrollProxy = scrollProxy  // 弱代理
        }

        @objc func boundsDidChange(_ notification: Notification) {
            emitVisibleRange()  // 滚了就报
        }

        /// 滚动后告诉翻译同步。
        func emitVisibleRange() {
            guard let textView, !textView.hasMarkedText(), !isComposingText else { return }  // 组字中范围不准
            let range = scrollProxy?.visibleCharacterRange()  // 代理算过就用
                ?? visibleCharacterRange(in: textView)  // 否则本地算
            let offset = scrollView?.contentView.bounds.origin.y ?? 0  // 像素偏移给同步
            onVisibleRangeChange?(range, offset)  // 翻译对滚
        }

        /// 当前可视字符。
        private func visibleCharacterRange(in textView: NSTextView) -> NSRange {
            guard let layoutManager = textView.layoutManager,  // TextKit 齐
                  let textContainer = textView.textContainer else {  // 缺了给空
                return NSRange(location: 0, length: 0)  // 对滚当没看见
            }
            var visibleRect = textView.visibleRect  // 视口
            let origin = textView.textContainerOrigin  // container 相对视图
            visibleRect.origin.x -= origin.x  // 换成 container 坐标
            visibleRect.origin.y -= origin.y  // 含 inset
            let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)  // 可见字形
            return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)  // 换成字符 range
        }

        /// 写回绑定，避开 IME。
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }  // 不是我们就忽略
            guard !isUpdatingFromBinding else { return }  // 灌绑定不当输入

            isComposingText = textView.hasMarkedText()  // 记下，update 用
            guard !isComposingText else { return }  // 拼音未上屏不写绑定

            isUpdatingFromView = true  // 挡住 update 回灌
            text = textView.string  // 写回 VM
            isUpdatingFromView = false  // 解开
        }

        @objc func selectionDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }  // 不是我们就忽略
            guard !textView.hasMarkedText() else { return }  // 组字中选区是拼音

            let range = textView.selectedRange()  // 应是全文
            guard range.length > 0, let swiftRange = Range(range, in: textView.string) else {  // 失败当空
                onSelectionChange("", nil)  // 清
                return
            }
            onSelectionChange(String(textView.string[swiftRange]), range)  // 全文回 VM
        }

        /// 全选并记住。
        func selectAll() {
            guard let textView else { return }  // 已卸
            guard (textView.string as NSString).length > 0 else { return }  // 空页不选

            textView.window?.makeFirstResponder(textView)  // 全选要焦点
            textView.selectAll(nil)  // 系统全选

            let range = textView.selectedRange()  // 应是全文
            guard range.length > 0, let swiftRange = Range(range, in: textView.string) else {  // 失败当空
                onSelectionChange("", nil)  // 清
                return
            }
            onSelectionChange(String(textView.string[swiftRange]), range)  // 全文回 VM
        }
    }
}

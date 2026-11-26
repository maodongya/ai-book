import SwiftUI
import UIKit

/// 对照表里可编辑译文格。关闭内滚，按内容增高，避免只露一行。
struct IOSCompareGrowingTextView: UIViewRepresentable {
  @Binding var text: String
  var font: UIFont
  var textColor: UIColor
  var highlightColor: UIColor?

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeUIView(context: Context) -> GrowingUITextView {
    let view = GrowingUITextView()
    view.backgroundColor = .clear
    view.isScrollEnabled = false // 高度交给外层 ScrollView
    view.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
    view.textContainer.lineFragmentPadding = 0
    view.font = font
    view.textColor = textColor
    view.delegate = context.coordinator
    view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return view
  }

  func updateUIView(_ textView: GrowingUITextView, context: Context) {
    context.coordinator.parent = self
    textView.font = font
    textView.textColor = textColor
    textView.backgroundColor = highlightColor ?? .clear
    if textView.text != text {
      textView.text = text // 外部对齐块更新时同步
    }
    textView.invalidateIntrinsicContentSize()
  }

  final class Coordinator: NSObject, UITextViewDelegate {
    var parent: IOSCompareGrowingTextView

    init(_ parent: IOSCompareGrowingTextView) {
      self.parent = parent
    }

    func textViewDidChange(_ textView: UITextView) {
      parent.text = textView.text // 写回当前对照块
      textView.invalidateIntrinsicContentSize()
    }
  }
}

/// 随文字变高的 UITextView。
final class GrowingUITextView: UITextView {
  override var intrinsicContentSize: CGSize {
    let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width - 68
    let fitting = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    return CGSize(width: UIView.noIntrinsicMetric, height: max(44, ceil(fitting.height)))
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    invalidateIntrinsicContentSize() // 换行时拉高单元格
  }
}
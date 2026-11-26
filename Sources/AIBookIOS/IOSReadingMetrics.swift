import CoreGraphics
import SwiftUI

/// 阅读页尺寸：分页与 `IOSReadingPage` 边距一致。
enum IOSReadingMetrics {
    /// 顶栏+页脚可见时占去的竖直空间（与 SwiftUI 布局大致对齐）。
    static func chromeVerticalReserve(chromeVisible: Bool) -> CGFloat {
        guard chromeVisible else { return 0 }
        return topBarHeight + footerBlockHeight + IOSLayout.readingTextPadding
    }

    static let topBarHeight: CGFloat = 64
    static let footerBlockHeight: CGFloat = 44

    /// TextKit 分页用可排字区域。按顶栏隐藏时的最大高度算，避免沉浸后底部空一大截。
    static func paginationContentSize(in geo: GeometryProxy) -> CGSize {
        let insets = geo.safeAreaInsets
        let container = CGSize(
            width: geo.size.width,
            height: geo.size.height - insets.top - insets.bottom
        )
        let pageWidth = IOSReadingPreferences.singlePageWidth(in: container)
        let pad = IOSLayout.readingTextPadding
        let top = pad + 8 // 与 `readingBody` 顶栏隐藏时的 top 一致
        let width = max(1, pageWidth - 2 * pad)
        let height = max(1, container.height - top - pad)
        return CGSize(width: width, height: height)
    }
}
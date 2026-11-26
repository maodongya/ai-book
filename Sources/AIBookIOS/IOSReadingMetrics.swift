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
        let top = pad + 6 // 与沉浸阅读顶边距一致
        let bottom = pad + 4 // 略留页脚呼吸，其余交给 TextKit 填满
        let width = max(1, pageWidth - 2 * pad)
        let height = max(1, container.height - top - bottom)
        return CGSize(width: width, height: height)
    }
}
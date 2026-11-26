import CoreGraphics
import UIKit

/// iOS 阅读偏好。iPhone 与 iPad 统一单页全屏，保留左右滑/点按翻页。
enum IOSReadingPreferences {
    private static let dualPageKey = "aiBook.ios.readingDualPage"

    /// 历史开关保留写入，但不再启用双页并排。
    static var dualPageEnabled: Bool {
        get { false }
        set { UserDefaults.standard.set(newValue, forKey: dualPageKey) }
    }

    /// 始终单页，横竖屏同一套翻页。
    static func showsDualSpread(containerSize: CGSize) -> Bool {
        _ = containerSize
        return false
    }

    /// 单页内容区宽度即为容器宽度。
    static func singlePageWidth(in containerSize: CGSize) -> CGFloat {
        max(1, containerSize.width)
    }

    /// 双页遗留索引对齐；单页时直接返回原索引。
    static func spreadLeftIndex(_ index: Int) -> Int {
        max(0, index)
    }
}
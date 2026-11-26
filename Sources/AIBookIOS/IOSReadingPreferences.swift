import CoreGraphics
import UIKit

/// iPad 阅读偏好。仅宽屏横屏才生效。
enum IOSReadingPreferences {
    private static let dualPageKey = "aiBook.ios.readingDualPage"

    static var dualPageEnabled: Bool {
        get {
            guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
            if UserDefaults.standard.object(forKey: dualPageKey) == nil { return true } // 默认双页
            return UserDefaults.standard.bool(forKey: dualPageKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dualPageKey)
        }
    }

    /// 横屏 iPad 且用户开了双页。
    static func showsDualSpread(containerSize: CGSize) -> Bool {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
        guard dualPageEnabled else { return false }
        return containerSize.width > containerSize.height
    }

    /// 双页时单页内容区宽度。
    static func singlePageWidth(in containerSize: CGSize) -> CGFloat {
        guard showsDualSpread(containerSize: containerSize) else { return containerSize.width }
        let gutter: CGFloat = 18
        return max(1, (containerSize.width - gutter) / 2)
    }

    /// 双页时左页索引收成偶数，避免半幅错位。
    static func spreadLeftIndex(_ index: Int) -> Int {
        max(0, index - (index % 2))
    }
}
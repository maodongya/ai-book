import CoreGraphics
import Foundation
import SwiftUI
import UIKit

/// 宽窄决定单页还是并排。iPhone 横屏仍走单页，避免压出一条书脊。
enum IOSLayout {
    static let sideBySideMinWidth: CGFloat = 1000 // iPad 横屏并排阈值
    /// 页标题距正文区顶缘（顶栏已用 safeAreaInset 占位）
    static let pageTitleTopPadding: CGFloat = 12
    static let pageTitleHorizontalPadding: CGFloat = 20
    /// 阅读页正文与屏幕边缘留白。iPad 略小以多排字。
    static var readingTextPadding: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 20 : 24
    }

    static func usesSideBySide(width: CGFloat) -> Bool {
        width >= sideBySideMinWidth // 够宽才原文+副页并排
    }
}

/// 阅读页松手时是否翻页。超过页宽约三分之一才离开本页。
enum IOSReadingTurn {
    static func pageDelta(translation: CGFloat, pageWidth: CGFloat) -> Int {
        guard pageWidth > 0 else { return 0 } // 未布局完成不翻
        let threshold = pageWidth / 3 // 三分之一屏为翻页门槛
        if translation <= -threshold { return 1 } // 左滑下一页
        if translation >= threshold { return -1 } // 右滑上一页
        return 0 // 回弹留本页
    }
}
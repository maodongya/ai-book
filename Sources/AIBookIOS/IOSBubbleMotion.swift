import CoreGraphics
import Foundation

/// 气泡菜单的两段动作：先向右拉开，再向下展开。两段都要慢，不能一下弹开。
enum IOSBubbleMotion {
    /// 半圆向右拉成面板的时长。
    static let pullOpenDuration: TimeInterval = 0.72
    /// 菜单向下展开的时长。
    static let dropDownDuration: TimeInterval = 0.9
    /// 拉开之后再等一会儿，才开始向下落。
    static let dropDownDelay: TimeInterval = 0.48

    /// 已拉开但还没到下落时刻时，菜单保持收着。
    static func menuVisible(opened: Bool, elapsed: TimeInterval) -> Bool {
        guard opened else { return false } // 没按气泡就不出现菜单
        return elapsed >= dropDownDelay // 先完成向右，再允许向下
    }
}

/// 宽窄决定单页还是并排。iPhone 横屏仍走单页，避免压出一条书脊。
enum IOSLayout {
    /// 到这个宽度才并排。iPhone 横屏低于它，iPad 横屏高于它。
    static let sideBySideMinWidth: CGFloat = 1000

    /// 当前容器够不够把原文和助手并排放。
    static func usesSideBySide(width: CGFloat) -> Bool {
        width >= sideBySideMinWidth // 窄于这条立刻回到单页
    }
}

/// 阅读页松手时是否翻页。超过页宽约三分之一才离开本页。
enum IOSReadingTurn {
    /// 向左滑下一页，向右滑上一页，不够阈值就留在本页。
    static func pageDelta(translation: CGFloat, pageWidth: CGFloat) -> Int {
        guard pageWidth > 0 else { return 0 } // 还没量到页宽时不翻
        let threshold = pageWidth / 3 // 设计写的大约三分之一
        if translation <= -threshold { return 1 } // 手指向左，正文前进
        if translation >= threshold { return -1 } // 手指向右，正文后退
        return 0 // 没过线，页面弹回
    }
}

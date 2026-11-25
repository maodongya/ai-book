import SwiftUI

/// iOS 入口。Mac 窗口仍由 AIBookApp 负责，这里不引用它。
@main
struct AIBookIOSApp: App {
    var body: some Scene {
        WindowGroup {
            IOSRootView() // 手机一次一页，宽屏再并排
        }
    }
}

import Foundation

/// Technical stack identity for AIBook (command #2): native Swift + SwiftUI macOS app.
enum SwiftPlatform {
    static let implementationLabel = "Swift · SwiftUI"
    static let minimumMacOS = "13.0"
    static let packageSwiftVersion = "5.9"

    static var runtimeDescription: String {
        "原生 macOS \(implementationLabel)，最低系统 macOS \(minimumMacOS)+"
    }

    static var aboutLines: [String] {
        [
            "AIBook 使用 Swift 与 SwiftUI 实现，Swift Package Manager 构建。",
            "目标平台 macOS \(minimumMacOS)+，swift-tools-version \(packageSwiftVersion)。",
            "Cursor 桥接（cursor-bridge）为 Node.js 辅助模块；核心 UI 与业务逻辑均为 Swift。"
        ]
    }
}

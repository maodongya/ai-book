import Foundation

/// AIBook 的技术栈身份：原生 Swift + SwiftUI 的 macOS 应用。不负责探测本机能力或改构建脚本。
enum SwiftPlatform {
    /// 对外展示用的实现标签，只给关于页和命令输出读，不参与编译条件。
    static let implementationLabel = "Swift · SwiftUI"
    /// 声明支持的最低 macOS，须与 Package.swift 的 platforms 对齐。
    static let minimumMacOS = "13.0"
    /// Package.swift 的 swift-tools-version，只用于关于页说明。
    static let packageSwiftVersion = "5.9"

    /// 一行运行时描述，拼给需要「现在跑在什么栈上」的 UI。
    static var runtimeDescription: String {
        "原生 macOS \(implementationLabel)，最低系统 macOS \(minimumMacOS)+" // 从常量插值，避免关于页和声明各写一套版本
    }

    /// 关于页多行说明：Swift 是主体，Node 桥只是辅助。
    static var aboutLines: [String] {
        [
            "AIBook 使用 Swift 与 SwiftUI 实现，Swift Package Manager 构建。", // 主体技术栈，给用户读，不是构建条件
            "目标平台 macOS \(minimumMacOS)+，swift-tools-version \(packageSwiftVersion)。", // 插值常量，改版本只改上面三处
            "Cursor 桥接（cursor-bridge）为 Node.js 辅助模块；核心 UI 与业务逻辑均为 Swift。", // 划清 Node 只做桥，不承担业务
        ]
    }
}

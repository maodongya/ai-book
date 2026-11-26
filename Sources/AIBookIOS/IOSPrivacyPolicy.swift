import Foundation

/// 与 Mac `PrivacyPolicy` 同源；上架前填入公开网页地址。
enum PrivacyPolicy {
    static let publicURL: URL? = nil // 非空时设置页与隐私视图展示外链
}
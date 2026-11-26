#if DEBUG
import Foundation

/// 模拟器截图用。`simctl launch … --args -SnapshotTranslationCompare`
enum IOSSnapshotHints {
    static var translationCompare: Bool {
        ProcessInfo.processInfo.arguments.contains("-SnapshotTranslationCompare")
    }
}
#endif
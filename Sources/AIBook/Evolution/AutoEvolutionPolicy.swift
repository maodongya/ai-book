import Foundation

/// 是否在重启后自动开下一轮进化。只做布尔判断，不碰文件、不改队列。
public enum AutoEvolutionPolicy {
    /// 三个条件同时成立才自动开：用户开了开关、链还在、队列里还有待办。
    public static func shouldAutoStart(
        autoEvolutionEnabled: Bool,
        isChainActive: Bool,
        pendingCount: Int
    ) -> Bool {
        autoEvolutionEnabled && isChainActive && pendingCount > 0 // 任一为假都停，避免空转重启
    }
}

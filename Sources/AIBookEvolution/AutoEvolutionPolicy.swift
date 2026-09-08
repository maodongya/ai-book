import Foundation

public enum AutoEvolutionPolicy {
    public static func shouldAutoStart(
        autoEvolutionEnabled: Bool,
        isChainActive: Bool,
        pendingCount: Int
    ) -> Bool {
        autoEvolutionEnabled && isChainActive && pendingCount > 0
    }
}

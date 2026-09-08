import Foundation

public enum EvolutionToolPolicy {
    public static func isMutating(_ name: String) -> Bool {
        switch name.lowercased() {
        case "read", "read_file", "grep", "glob", "glob_file_search":
            return false
        default:
            return true
        }
    }
}

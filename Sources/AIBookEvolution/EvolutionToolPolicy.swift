import Foundation

/// 判断进化工具是否会改仓库。只读工具放行预览，其它一律当写操作。
public enum EvolutionToolPolicy {
    /// 名字归一成小写后再比，兼容 read_file / glob_file_search 等别名。
    public static func isMutating(_ name: String) -> Bool {
        switch name.lowercased() {
        case "read", "read_file", "grep", "glob", "glob_file_search":
            return false // 只读，确认计划阶段可以跑
        default:
            return true // 未知工具当会改文件，避免漏拦
        }
    }
}

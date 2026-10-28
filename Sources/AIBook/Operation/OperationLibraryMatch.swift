import Foundation

/// 按文件名在书库名单里找唯一一本。零本或多本都不猜。
enum OperationLibraryMatch {
    /// 成功时返回名单里的原文件名，方便再去对 URL。
    static func uniqueName(query: String, fileNames: [String]) -> Outcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = fileNames.filter { name in
            if name.caseInsensitiveCompare(trimmed) == .orderedSame { return true } // 全名相等
            guard !trimmed.contains(".") else { return false } // 用户说了扩展名就不再用主文件名
            let stem = (name as NSString).deletingPathExtension
            return stem.caseInsensitiveCompare(trimmed) == .orderedSame // 「乙」对上「乙.txt」
        }
        var seen = Set<String>() // 同一名字只算一本
        var ordered: [String] = []
        for name in matches {
            if seen.insert(name.lowercased()).inserted {
                ordered.append(name) // 保留第一次出现的写法
            }
        }
        if ordered.count == 1, let only = ordered.first {
            return .unique(only)
        }
        if ordered.isEmpty {
            return .skipped(.libraryNoMatch)
        }
        return .skipped(.libraryMultipleMatches)
    }

    /// 唯一文件名，或跳过原因。
    enum Outcome: Equatable {
        case unique(String)
        case skipped(OperationSkipReason)
    }
}

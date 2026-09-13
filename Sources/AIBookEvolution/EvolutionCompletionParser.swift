import Foundation

/// 从模型回复里抽出「第 N 条已完成」的摘要。先认机器块，再认编号行。
public enum EvolutionCompletionParser {
    /// 给队列写完成说明。两种格式都没有则 nil，调用方不要空写已完成。
    public static func summary(from reply: String, number: Int) -> String? {
        if let blockSummary = parseDoneBlock(from: reply, number: number) {
            return blockSummary // 机器块优先，避免正文里的「已完成」误伤
        }
        return parseNumberedCompletedLine(from: reply, number: number)
    }

    /// 解析 <<<EVOLUTION_DONE>>> {json} <<<END>>> ，且 number 必须对上当前条目。
    private static func parseDoneBlock(from reply: String, number: Int) -> String? {
        let pattern = #"<<<EVOLUTION_DONE>>>\s*(\{[\s\S]*?\})\s*<<<END>>>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: reply,
                range: NSRange(reply.startIndex..., in: reply)
              ),
              let range = Range(match.range(at: 1), in: reply)
        else { return nil }

        guard let data = reply[range].data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let parsedNumber = object["number"] as? Int,
              parsedNumber == number, // 防串条
              let summary = object["summary"] as? String
        else { return nil }

        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 退回认「N、已完成：…」这种给人看的行。
    private static func parseNumberedCompletedLine(from reply: String, number: Int) -> String? {
        let prefix = "\(number)、"
        let completedPrefix = "\(number)、已完成"
        for line in reply.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(prefix) || trimmed.hasPrefix(completedPrefix) else { continue }
            guard trimmed.contains("已完成") else { continue } // 只要完成态，跳过/进行中不算
            for separator in ["已完成：", "已完成:"] {
                if let range = trimmed.range(of: separator) {
                    let summary = String(trimmed[range.upperBound...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return summary.isEmpty ? nil : summary
                }
            }
        }
        return nil
    }
}

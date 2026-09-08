import Foundation

public enum EvolutionCompletionParser {
    public static func summary(from reply: String, number: Int) -> String? {
        if let blockSummary = parseDoneBlock(from: reply, number: number) {
            return blockSummary
        }
        return parseNumberedCompletedLine(from: reply, number: number)
    }

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
              parsedNumber == number,
              let summary = object["summary"] as? String
        else { return nil }

        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func parseNumberedCompletedLine(from reply: String, number: Int) -> String? {
        let prefix = "\(number)、"
        let completedPrefix = "\(number)、已完成"
        for line in reply.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(prefix) || trimmed.hasPrefix(completedPrefix) else { continue }
            guard trimmed.contains("已完成") else { continue }
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

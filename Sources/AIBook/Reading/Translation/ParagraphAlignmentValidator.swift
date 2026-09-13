import Foundation

/// 整段严格对齐验收失败原因；对应 L10n 键由调用方展示。
enum ParagraphAlignmentValidationFailure: Equatable, Error {
    case countMismatch(expected: Int, actual: Int)
    case indexCoverage
    case emptyTranslation(index: Int)
    case sourceTextMismatch(index: Int)
    case anchoringIncomplete(expected: Int, actual: Int)

    /// 用户可见文案键；带参数的失败用 `BookL10n.format`。
    var messageKey: String {
        switch self {
        case .countMismatch:
            return "vm.error.paragraphAlign.countMismatch"
        case .indexCoverage:
            return "vm.error.paragraphAlign.indexCoverage"
        case .emptyTranslation:
            return "vm.error.paragraphAlign.emptyTranslation"
        case .sourceTextMismatch:
            return "vm.error.paragraphAlign.sourceMismatch"
        case .anchoringIncomplete:
            return "vm.error.paragraphAlign.anchoringIncomplete"
        }
    }
}

/// 整段模式 §5.3 验收门（V1–V5）。
enum ParagraphAlignmentValidator {
    /// 只验收 paragraph 级块；summary 不参与严格段对段。
    static func validate(
        blocks: [TranslationBlock],
        index: SourceParagraphIndex,
        requireSourceTextMatch: Bool
    ) -> Result<Void, ParagraphAlignmentValidationFailure> {
        let paragraphBlocks = blocks
            .filter { $0.level == .paragraph }
            .sorted { $0.order < $1.order }

        let expected = index.count
        let actual = paragraphBlocks.count
        guard expected > 0 else {
            return actual == 0 ? .success(()) : .failure(.countMismatch(expected: 0, actual: actual))
        }
        guard actual == expected else {
            return .failure(.countMismatch(expected: expected, actual: actual))
        }

        let orders = Set(paragraphBlocks.map(\.order))
        guard orders.count == expected, orders == Set(0..<expected) else {
            return .failure(.indexCoverage)
        }

        for block in paragraphBlocks {
            let trimmed = block.translationText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return .failure(.emptyTranslation(index: block.order))
            }
        }

        if requireSourceTextMatch {
            for block in paragraphBlocks {
                guard index.slices.indices.contains(block.order) else { continue }
                let expectedText = index.slices[block.order].text
                guard paragraphSourceTextsMatch(block.sourceText, expectedText) else {
                    return .failure(.sourceTextMismatch(index: block.order))
                }
            }
        }

        let anchored = paragraphBlocks.filter(\.isAnchored).count
        guard anchored == expected else {
            return .failure(.anchoringIncomplete(expected: expected, actual: anchored))
        }

        return .success(())
    }

    /// 空白归一后相等；与 Builder 侧一致。
    private static func paragraphSourceTextsMatch(_ lhs: String, _ rhs: String) -> Bool {
        normalize(lhs) == normalize(rhs)
    }

    /// 去首尾空白，中间连续空白压成单空格，方便比原文。
    private static func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

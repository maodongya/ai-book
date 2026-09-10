import Foundation

enum TranslationBlockLevel: String, Codable, Equatable {
    case paragraph
    case word
    case phrase
    case summary
}

struct TranslationBlock: Identifiable, Codable, Equatable {
    let id: UUID
    var sourceLocation: Int
    var sourceLength: Int
    var sourceText: String
    var translationText: String
    var note: String?
    var level: TranslationBlockLevel
    var order: Int
    var translationLocation: Int = 0
    var translationLength: Int = 0

    var sourceRange: NSRange {
        NSRange(location: sourceLocation, length: sourceLength)
    }

    var translationRange: NSRange {
        NSRange(location: translationLocation, length: translationLength)
    }

    var isAnchored: Bool {
        sourceLength > 0
    }

    var hasTranslationRange: Bool {
        translationLength > 0
    }

    init(
        id: UUID = UUID(),
        sourceRange: NSRange,
        sourceText: String,
        translationText: String,
        note: String? = nil,
        level: TranslationBlockLevel,
        order: Int
    ) {
        self.id = id
        self.sourceLocation = sourceRange.location
        self.sourceLength = sourceRange.length
        self.sourceText = sourceText
        self.translationText = translationText
        self.note = note
        self.level = level
        self.order = order
    }
}

enum TranslationAlignmentMode: String, Codable, Equatable {
    case paragraph
    case wordByWord
}

struct TranslationAlignment: Codable, Equatable {
    var mode: TranslationAlignmentMode
    var blocks: [TranslationBlock]
    var sourceContentHash: String
    var createdAt: Date
    var isStale: Bool
    /// 右表相对左页滚动的行偏移：+1 表示右表整体下移一行对照。
    var syncBlockOffset: Int
    /// 锁定后禁止整体对齐与偏移调整；单行编辑仍可用。
    var isLocked: Bool

    var anchoredBlockCount: Int {
        blocks.filter(\.isAnchored).count
    }

    init(
        mode: TranslationAlignmentMode,
        blocks: [TranslationBlock],
        sourceContentHash: String,
        createdAt: Date,
        isStale: Bool,
        syncBlockOffset: Int = 0,
        isLocked: Bool = false
    ) {
        self.mode = mode
        self.blocks = blocks
        self.sourceContentHash = sourceContentHash
        self.createdAt = createdAt
        self.isStale = isStale
        self.syncBlockOffset = syncBlockOffset
        self.isLocked = isLocked
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case blocks
        case sourceContentHash
        case createdAt
        case isStale
        case syncBlockOffset
        case isLocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(TranslationAlignmentMode.self, forKey: .mode)
        blocks = try container.decode([TranslationBlock].self, forKey: .blocks)
        sourceContentHash = try container.decode(String.self, forKey: .sourceContentHash)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isStale = try container.decode(Bool.self, forKey: .isStale)
        syncBlockOffset = try container.decodeIfPresent(Int.self, forKey: .syncBlockOffset) ?? 0
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
    }

    static func empty(mode: TranslationAlignmentMode, sourceHash: String) -> TranslationAlignment {
        TranslationAlignment(
            mode: mode,
            blocks: [],
            sourceContentHash: sourceHash,
            createdAt: Date(),
            isStale: false
        )
    }
}

enum TranslationSourceHasher {
    static func hash(_ text: String) -> String {
        let normalized = normalize(text)
        var hash: UInt64 = 5381
        for byte in normalized.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash)
    }

    static func normalize(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

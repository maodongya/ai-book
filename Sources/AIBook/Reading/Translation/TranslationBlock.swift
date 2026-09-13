import Foundation

/// 段/句/词。rawValue 已入档案勿改。
enum TranslationBlockLevel: String, Codable, Equatable {
    case paragraph
    case word
    case phrase
    case summary // 篇末总译，不同步滚动
}

/// 一块对齐：原文、译文、可选注。
struct TranslationBlock: Identifiable, Codable, Equatable {
    let id: UUID // 表格行稳定 id，拆行会新生
    var sourceLocation: Int // UTF-16，相对当前左页全文
    var sourceLength: Int // 0 表示还没对上原文
    var sourceText: String
    var translationText: String
    var note: String?
    var level: TranslationBlockLevel
    var order: Int // 阅读顺序，不是 sourceLocation
    var translationLocation: Int = 0 // 右页纯文本里的位置；表格模式可 0
    var translationLength: Int = 0

    /// 原文在整篇里的 UTF-16 范围。
    var sourceRange: NSRange {
        NSRange(location: sourceLocation, length: sourceLength)
    }

    /// 译文在译文篇里的 UTF-16 范围。
    var translationRange: NSRange {
        NSRange(location: translationLocation, length: translationLength)
    }

    /// 原文范围有效，才能跟滚和高亮。
    var isAnchored: Bool {
        sourceLength > 0 // 没锚定就不能同步滚动
    }

    /// 译文范围有效，对照表才能定位右列。
    var hasTranslationRange: Bool {
        translationLength > 0
    }

    /// sourceRange 拆成 location/length 存，旧档案兼容。
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

/// 整段或逐词。切换会重请求。
enum TranslationAlignmentMode: String, Codable, Equatable {
    case paragraph
    case wordByWord
}

/// 对齐数据从哪来；决定是否承诺严格段对段。
enum TranslationProvenance: String, Codable, Equatable {
    case aiParagraphJSON
    case aiWordByWordJSON
    case importedPlain
    case realignedHeuristic
}

/// 一篇的对齐结果，按源文 hash 缓存。
struct TranslationAlignment: Codable, Equatable {
    var mode: TranslationAlignmentMode
    var blocks: [TranslationBlock]
    var sourceContentHash: String // 和当前左页对不上则 isStale
    var createdAt: Date
    var isStale: Bool // 原文改过，滚动同步应停
    /// 右表相对左页滚动的行偏移：+1 表示右表整体下移一行对照。
    var syncBlockOffset: Int
    /// 锁定后禁止整体对齐与偏移调整；单行编辑仍可用。
    var isLocked: Bool
    var schemaVersion: Int
    /// 通过整段 AI 验收门后为 true；启发式对齐为 false。
    var strictParagraphValidated: Bool
    var provenance: TranslationProvenance

    /// 钉住原文的块数，验收门用。
    var anchoredBlockCount: Int {
        blocks.filter(\.isAnchored).count
    }

    /// 内存里组一条对齐。旧档案缺的字段走默认。
    init(
        mode: TranslationAlignmentMode,
        blocks: [TranslationBlock],
        sourceContentHash: String,
        createdAt: Date,
        isStale: Bool,
        syncBlockOffset: Int = 0,
        isLocked: Bool = false,
        schemaVersion: Int = 1,
        strictParagraphValidated: Bool = false,
        provenance: TranslationProvenance = .aiParagraphJSON
    ) {
        self.mode = mode
        self.blocks = blocks
        self.sourceContentHash = sourceContentHash
        self.createdAt = createdAt
        self.isStale = isStale
        self.syncBlockOffset = syncBlockOffset
        self.isLocked = isLocked
        self.schemaVersion = schemaVersion
        self.strictParagraphValidated = strictParagraphValidated
        self.provenance = provenance
    }

    /// 旧档案缺 syncBlockOffset/isLocked 当 0/false。
    enum CodingKeys: String, CodingKey {
        case mode
        case blocks
        case sourceContentHash
        case createdAt
        case isStale
        case syncBlockOffset
        case isLocked
        case schemaVersion
        case strictParagraphValidated
        case provenance
    }

    /// 解码对齐档案。缺字段用 0 / false / 1 / aiParagraphJSON。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(TranslationAlignmentMode.self, forKey: .mode)
        blocks = try container.decode([TranslationBlock].self, forKey: .blocks)
        sourceContentHash = try container.decode(String.self, forKey: .sourceContentHash)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isStale = try container.decode(Bool.self, forKey: .isStale)
        syncBlockOffset = try container.decodeIfPresent(Int.self, forKey: .syncBlockOffset) ?? 0 // 旧档案没有偏移
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        strictParagraphValidated = try container.decodeIfPresent(Bool.self, forKey: .strictParagraphValidated) ?? false
        provenance = try container.decodeIfPresent(TranslationProvenance.self, forKey: .provenance) ?? .aiParagraphJSON
    }

    /// 占位对齐：hash 先记上，blocks 空。
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

/// 源文指纹。改算法会让缓存全失效。
enum TranslationSourceHasher {
    /// djb2。只作相等判断，不防碰撞攻击。
    static func hash(_ text: String) -> String {
        let normalized = normalize(text)
        var hash: UInt64 = 5381 // djb2 种子
        for byte in normalized.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash)
    }

    /// NFC + 换行归一。改这里等于换缓存键。
    static func normalize(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

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

    var anchoredBlockCount: Int {
        blocks.filter(\.isAnchored).count
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
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var hash: UInt64 = 5381
        for byte in normalized.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash)
    }
}

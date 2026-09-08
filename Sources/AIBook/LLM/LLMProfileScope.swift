import Foundation

/// Separates reading (book) LLM profiles from evolution LLM profiles.
enum LLMProfileScope: String, Codable, CaseIterable {
    case book
    case evolution
}

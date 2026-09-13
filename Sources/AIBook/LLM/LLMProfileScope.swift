import Foundation

/// 把读书用的 LLM 档案和进化用的档案分开存，避免改讲解模型冲掉进化模型。
enum LLMProfileScope: String, Codable, CaseIterable {
    case book // 左页讲解 / 翻译 / 名著补充
    case evolution // 右页自进化
}

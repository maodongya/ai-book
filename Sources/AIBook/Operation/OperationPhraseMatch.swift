import Foundation

/// 听写常见口令的本地匹配。对上了就不请求模型，避免同音误识别。
enum OperationPhraseMatch {
    /// 高置信度时返回计划；对不上返回 nil，交给 OperationPlanner 走模型。
    /// language 缺省用当前界面语言。中文口令始终有效，其它语言再认按钮上的字。
    static func localPlan(for utterance: String, language: BookAppLanguage? = nil) -> OperationPlan? {
        let spoken = replaceSaveHomophones(utterance) // 包存/报存先还原成保存
        let text = normalize(spoken)
        guard !text.isEmpty else { return nil }
        let language = language ?? BookL10n.currentLanguage
        if let action = match(text, utterance: spoken, language: language) {
            return OperationPlan(actions: [action])
        }
        return nil
    }

    /// 更具体的口令先匹配。按钮上的原文、翻译、讲解就是口令范围。
    private static func match(_ text: String, utterance: String, language: BookAppLanguage) -> OperationAction? {
        if let action = speechControl(in: text, language: language) { return action }
        if let action = readAloud(in: text, language: language) { return action }
        if let action = explanationCommand(in: text, language: language) { return action }
        if let action = explainAction(in: text, language: language) { return action }
        if let action = translationCommand(in: text, language: language) { return action }
        if let action = sourceCommand(in: text, utterance: utterance, language: language) { return action }
        return layoutCommand(in: text, language: language)
    }

    /// 非中文界面时，听写里出现当前按钮文案也算口令。中文仍只用下面的手写表，避免「停止」被放宽。
    private static func matchesButton(_ text: String, keys: [String], language: BookAppLanguage) -> Bool {
        guard usesButtonTitles(language) else { return false }
        for key in keys {
            let title = normalize(BookL10nCatalog.string(forKey: key, language: language))
            guard title != normalize(key), title.count >= 3 else { continue } // 目录缺失时不要拿 key 当口令
            if title.count < 8 {
                if text == title { return true } // Stop、Spread 太短，只认整句
            } else if text.contains(title) {
                return true
            }
        }
        return false
    }

    /// 简体界面不叠加按钮文案。跟随系统且本机是中文时同样不叠加。
    private static func usesButtonTitles(_ language: BookAppLanguage) -> Bool {
        switch language {
        case .zhHans:
            return false
        case .system:
            return !BookL10n.activeLocale.identifier.lowercased().hasPrefix("zh")
        default:
            return true
        }
    }

    /// 朗读控制优先于「停止讲解」，避免把停止朗读听成停止生成。
    private static func speechControl(in text: String, language: BookAppLanguage) -> OperationAction? {
        if text.contains("停止朗读") || matchesButton(text, keys: [
            "action.stopExplanationSpeech",
            "action.stopTranslationSpeech",
            "action.readExplanationStop",
            "operation.action.stopSpeech",
        ], language: language) {
            return .stopSpeech
        }
        if text.contains("停止讲解") || text.contains("停止翻译") || text.contains("停止生成")
            || matchesButton(text, keys: ["operation.action.stopCurrentRun", "action.stop"], language: language) {
            return .stopCurrentRun
        }
        if text.contains("暂停") || matchesButton(text, keys: [
            "action.pauseExplanationSpeech",
            "action.pauseTranslationSpeech",
            "operation.action.pauseSpeech",
        ], language: language) {
            return .pauseSpeech
        }
        if text.contains("继续") || matchesButton(text, keys: [
            "action.resumeExplanationSpeech",
            "action.resumeTranslationSpeech",
            "operation.action.resumeSpeech",
        ], language: language) {
            return .resumeSpeech
        }
        return nil
    }

    /// 朗读必须带原文、翻译或讲解，选区比全文更具体。按钮文案同样先认选区。
    private static func readAloud(in text: String, language: BookAppLanguage) -> OperationAction? {
        if matchesButton(text, keys: ["menu.readOriginalSelection", "operation.action.readOriginalSelection"], language: language) {
            return .readOriginalSelection
        }
        if matchesButton(text, keys: ["menu.readOriginalFull", "operation.action.readOriginalFull"], language: language) {
            return .readOriginalFull
        }
        if matchesButton(text, keys: ["operation.action.readTranslationSelection"], language: language) {
            return .readTranslationSelection
        }
        if matchesButton(text, keys: ["action.readTranslation", "operation.action.readTranslationFull"], language: language) {
            return .readTranslationFull
        }
        if matchesButton(text, keys: ["operation.action.readExplanationSelection"], language: language) {
            return .readExplanationSelection
        }
        if matchesButton(text, keys: ["action.readExplanation", "operation.action.readExplanationFull"], language: language) {
            return .readExplanationFull
        }
        guard text.contains("朗读") || text.hasPrefix("读") else { return nil }
        if text.contains("原文") {
            return text.contains("选") ? .readOriginalSelection : .readOriginalFull
        }
        if text.contains("翻译") || text.contains("译文") {
            return text.contains("选") ? .readTranslationSelection : .readTranslationFull
        }
        if text.contains("讲解") {
            return text.contains("选") ? .readExplanationSelection : .readExplanationFull
        }
        return nil
    }

    /// 讲解文稿和对照，先于「讲解」生成，避免「保存讲解」被当成讲解选区。
    private static func explanationCommand(in text: String, language: BookAppLanguage) -> OperationAction? {
        if text.contains("新建讲解") || matchesButton(text, keys: ["action.newExplanation", "operation.action.newExplanation"], language: language) {
            return .newExplanation
        }
        if text.contains("打开讲解") || matchesButton(text, keys: ["action.openExplanation", "operation.action.openExplanation"], language: language) {
            return .openExplanation
        }
        if text.contains("保存讲解") || matchesButton(text, keys: ["action.saveExplanation", "operation.action.saveExplanation"], language: language) {
            return .saveExplanation
        }
        if text.contains("清空讲解") || matchesButton(text, keys: ["action.clearExplanation", "operation.action.clearExplanation"], language: language) {
            return .clearExplanation
        }
        if text.contains("全选讲解") || matchesButton(text, keys: ["action.selectAllExplanation", "operation.action.selectAllExplanation"], language: language) {
            return .selectAllExplanation
        }
        if text.contains("对齐讲解") || matchesButton(text, keys: ["explanation.alignSource", "operation.action.alignExplanation"], language: language) {
            return .alignExplanation
        }
        if text.contains("解锁讲解") || matchesButton(text, keys: ["explanation.unlock", "operation.action.unlockExplanation"], language: language) {
            return .unlockExplanation
        }
        if text.contains("锁定讲解") || matchesButton(text, keys: ["explanation.lock", "operation.action.lockExplanation"], language: language) {
            return .lockExplanation
        }
        if text.contains("讲解对照") || matchesButton(text, keys: ["explanation.tableCompare", "operation.action.toggleExplanationTable"], language: language) {
            return .toggleExplanationTable
        }
        if text.contains("显示讲解") || matchesButton(text, keys: ["explanation.displayLanguage"], language: language) {
            return .showAssistantPanel("explanation")
        }
        return nil
    }

    /// 翻译文稿和生成。逐字、整段比笼统的「翻译」更具体。
    private static func translationCommand(in text: String, language: BookAppLanguage) -> OperationAction? {
        if text.contains("逐字翻译") || text.contains("逐词翻译") || matchesButton(text, keys: [
            "action.wordTranslation",
            "operation.action.translateWordByWord",
        ], language: language) {
            return .translateWordByWord
        }
        if text.contains("整段翻译") || matchesButton(text, keys: [
            "action.paragraphTranslation",
            "operation.action.translateParagraph",
        ], language: language) {
            return .translateParagraph
        }
        if text.contains("打开翻译") || matchesButton(text, keys: ["operation.action.openTranslation"], language: language) {
            return .openTranslation
        }
        if text.contains("保存翻译") || matchesButton(text, keys: ["operation.action.saveTranslation"], language: language) {
            return .saveTranslation
        }
        if text.contains("清空翻译") || matchesButton(text, keys: ["action.clearTranslation", "operation.action.clearTranslation"], language: language) {
            return .clearTranslation
        }
        if text.contains("全选翻译") || matchesButton(text, keys: [
            "action.selectAllTranslation",
            "menu.selectAllTranslation",
            "operation.action.selectAllRight",
        ], language: language) {
            return .selectAllRight
        }
        if text.contains("对齐翻译") || text.contains("对齐原文") || matchesButton(text, keys: [
            "translation.alignTranslation",
            "operation.action.alignTranslation",
        ], language: language) {
            return .alignTranslation
        }
        if text.contains("解锁翻译") || text.contains("解锁对照") || matchesButton(text, keys: [
            "translation.unlock",
            "operation.action.unlockTranslation",
        ], language: language) {
            return .unlockTranslation
        }
        if text.contains("锁定翻译") || text.contains("锁定对照") || matchesButton(text, keys: [
            "translation.lock",
            "operation.action.lockTranslation",
        ], language: language) {
            return .lockTranslation
        }
        if text.contains("翻译对照") || text == "表格对照" || matchesButton(text, keys: [
            "translation.tableCompare",
            "operation.action.toggleTranslationTable",
        ], language: language) {
            return .toggleTranslationTable
        }
        if text.contains("显示翻译") || text.contains("显示译文") || matchesButton(text, keys: ["translation.displayLanguage"], language: language) {
            return .showAssistantPanel("translation")
        }
        return nil
    }

    /// 原文文件操作。目录要先于「打开原文」，否则目录口令会被打开文件吃掉。
    private static func sourceCommand(in text: String, utterance: String, language: BookAppLanguage) -> OperationAction? {
        if text.contains("原文新建") || text.contains("新建原文") || text == "新建"
            || matchesButton(text, keys: ["action.newSource", "operation.action.newDocument"], language: language) {
            return .newDocument
        }
        if text.contains("原文打开目录") || text.contains("打开原文目录") || text.contains("打开目录")
            || matchesButton(text, keys: ["action.openDirectory", "action.openDirectoryShort", "operation.action.openDirectoryPanel"], language: language) {
            return .openDirectoryPanel
        }
        if text.contains("原文打开") || text.contains("打开原文") || text == "打开" || text.contains("打开文件") || text.contains("打开文本")
            || matchesButton(text, keys: ["action.openSource", "action.openFile", "operation.action.openFilePanel"], language: language) {
            return .openFilePanel
        }
        if text.contains("原文全选") || text.contains("全选原文") || text.contains("全选左页")
            || matchesButton(text, keys: ["menu.selectAllLeft", "operation.action.selectAllLeft"], language: language) {
            return .selectAllLeft
        }
        if text.contains("原文导出") || text.contains("导出原文") || text.contains("导出选中")
            || matchesButton(text, keys: ["action.exportSelection", "operation.action.saveSelectionAs"], language: language) {
            return .saveSelectionAs
        }
        if text.contains("原文补充") || text.contains("名著补充") || text.contains("名著补全")
            || matchesButton(text, keys: ["action.classicSupplement", "operation.action.supplementClassic"], language: language) {
            return .supplementClassic
        }
        if matchesButton(text, keys: ["action.saveAIBook", "operation.action.saveAsAIBook"], language: language) {
            return .saveAsAIBook(nil) // 只说按钮时用默认文件名
        }
        if let action = saveAsAIBookAction(normalized: text, utterance: utterance) { return action }
        if matchesButton(text, keys: ["action.saveSourceAs", "operation.action.saveAs"], language: language) {
            return .saveAs
        }
        if matchesButton(text, keys: ["action.saveSource", "operation.action.save"], language: language) {
            return .save
        }
        return saveAction(in: text)
    }

    /// 阅读布局。学习模式和阅读模式都是同一个切换。
    private static func layoutCommand(in text: String, language: BookAppLanguage) -> OperationAction? {
        if text.contains("阅读模式") || text.contains("原文阅读") || text.contains("阅读原文") || text.contains("学习模式") || text.contains("退出阅读")
            || matchesButton(text, keys: ["action.enterReading", "mode.reading", "mode.learning"], language: language) {
            return .toggleReadingMode
        }
        if text.contains("原文全屏") || text.contains("左全屏")
            || matchesButton(text, keys: ["layout.leftFullscreen"], language: language) {
            return .setPaneFocus("leading")
        }
        if text.contains("右全屏") || matchesButton(text, keys: ["layout.rightFullscreen"], language: language) {
            return .setPaneFocus("trailing")
        }
        if text == "双页" || text.contains("恢复双页") || matchesButton(text, keys: ["layout.spread"], language: language) {
            return .setPaneFocus("both")
        }
        if text.contains("读书助手") || matchesButton(text, keys: ["tab.readingAssistant"], language: language) {
            return .showRightPage("assistant")
        }
        return nil
    }

    /// 听写常把「保存」听成同音字。只替换这几个，避免碰到讲解口令。
    private static func replaceSaveHomophones(_ utterance: String) -> String {
        ["包存", "报存", "爆存", "宝存", "保村"].reduce(utterance) { partial, homophone in
            partial.replacingOccurrences(of: homophone, with: "保存")
        }
    }

    private static func normalize(_ utterance: String) -> String {
        let scalars = utterance.unicodeScalars.filter { !isIgnorable($0) } // 保·存、保\u{200b}存 都收成保存
        return String(String.UnicodeScalarView(scalars)).lowercased()
    }

    /// 空白、标点和看不见的格式字符不参与口令比较。
    private static func isIgnorable(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .spaceSeparator, .lineSeparator, .paragraphSeparator, .control, .format,
             .dashPunctuation, .openPunctuation, .closePunctuation, .connectorPunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation:
            return true
        default:
            return false
        }
    }

    private static func explainAction(in text: String, language: BookAppLanguage) -> OperationAction? {
        if matchesButton(text, keys: ["action.explainFull", "operation.action.explainFullText"], language: language) {
            return .explainFullText
        }
        if matchesButton(text, keys: ["action.explainSelection", "operation.action.explainSelection"], language: language) {
            return .explainSelection
        }
        if isExplainFullPhrase(text) {
            return .explainFullText
        }
        if isExplainSelectionPhrase(text) {
            return .explainSelection
        }
        return nil
    }

    /// 全文讲解：含「全文+讲解」，且不是朗读讲解。
    private static func isExplainFullPhrase(_ text: String) -> Bool {
        if text.contains("全文讲解") || text.contains("讲解全文") {
            return !isReadExplanationPhrase(text)
        }
        guard text.contains("全文"), text.contains("讲解") else { return false }
        return !isReadExplanationPhrase(text)
    }

    /// 选区讲解：明确说选区/选中，或只说「讲解」且不带全文。
    private static func isExplainSelectionPhrase(_ text: String) -> Bool {
        if text.contains("全文") || isReadExplanationPhrase(text) || isExplanationFilePhrase(text) {
            return false
        }
        if text.contains("讲解选区") || text.contains("选区讲解") || text.contains("选择讲解") || text.contains("讲选区") {
            return true
        }
        return text.contains("讲解")
    }

    /// 文稿和对照口令里的「讲解」不是生成讲解。
    private static func isExplanationFilePhrase(_ text: String) -> Bool {
        ["保存", "打开", "新建", "清空", "全选", "对齐", "锁定", "解锁", "显示", "对照"].contains { text.contains($0) }
    }

    private static func isReadExplanationPhrase(_ text: String) -> Bool {
        text.contains("朗读") || text.contains("读讲解") || text.hasPrefix("读")
    }

    private static func saveAction(in text: String) -> OperationAction? {
        if isSaveSelectionPhrase(text) {
            return .saveSelectionAs
        }
        if isSaveAsPhrase(text) {
            return .saveAs
        }
        if isSavePhrase(text) {
            return .save
        }
        return nil
    }

    /// 选区另存为；无选区时由 OperationExecutor 跳过。
    private static func isSaveSelectionPhrase(_ text: String) -> Bool {
        guard text.contains("选区") else { return false }
        return text.contains("保存") || text.contains("另存") || text.contains("导出")
    }

    /// 系统另存为面板；带 AIBook 标记的走 saveAsAIBook。「保存为」和「另存为」一样。
    private static func isSaveAsPhrase(_ text: String) -> Bool {
        guard !hasAIBookMarker(text) else { return false }
        return text.contains("另存为") || text.contains("保存为") || text == "另存"
    }

    /// 保存当前文件（含 readme 笔记）；「保存为 xxx」留给另存或 AIBook。
    private static func isSavePhrase(_ text: String) -> Bool {
        if isShortSaveCommand(text) { return true }
        guard text.contains("保存") else { return false }
        if text.contains("讲解") || text.contains("翻译") { return false }
        if hasAIBookMarker(text) { return false }
        if text.contains("另存") || text.contains("保存为") { return false }
        if text.contains("选区") { return false }
        if text.contains("存为") || text.contains("存成") { return false }
        return true
    }

    /// 没说「保存」两个字，但就是存盘。
    private static func isShortSaveCommand(_ text: String) -> Bool {
        if text == "存盘" || text == "存一下" || text == "存档" { return true }
        return text.hasSuffix("存盘") || text.hasSuffix("存一下") || text.hasSuffix("存档")
    }

    private static func saveAsAIBookAction(normalized text: String, utterance: String) -> OperationAction? {
        guard isSaveAsAIBookPhrase(text) else { return nil }
        return .saveAsAIBook(extractAIBookSaveStem(from: utterance))
    }

    /// 口令里「保存为」后面的名字；只说 aibook 时不填，交给默认建议名。
    private static func extractAIBookSaveStem(from utterance: String) -> String? {
        var remainder = utterance
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "，。！？"))
        let prefixes = ["另存为", "保存为", "存成", "存为", "另存", "保存"]
        for prefix in prefixes where remainder.hasPrefix(prefix) {
            remainder = String(remainder.dropFirst(prefix.count))
            break
        }
        remainder = remainder
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "，。！？"))
        guard !remainder.isEmpty else { return nil }
        let norm = normalize(remainder)
        if norm == "aibook" || norm == "aiboo" || norm == "ai书" || norm == "ai" {
            return nil
        }
        return remainder
    }

    /// 另存为 `.aibook`：需同时像「保存」且像 AIBook（含听写截断 aiboo）。
    private static func isSaveAsAIBookPhrase(_ text: String) -> Bool {
        guard hasAIBookMarker(text) else { return false }
        return text.contains("保存") || text.contains("另存") || text.contains("存为") || text.contains("存成")
    }

    private static func hasAIBookMarker(_ text: String) -> Bool {
        text.contains("aibook") || text.contains("aiboo") || text.contains("ai书")
    }
}

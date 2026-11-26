import Foundation

/// iOS 这一次打开的书。只放界面要显示的正文，不接 Mac 的阅读会话。
@MainActor
final class IOSDocument: ObservableObject {
    /// 导航标题。没打开文件时为空。
    @Published var title = ""
    /// 原文。
    @Published var source = ""
    /// 原文页最近一次非空选区，讲解和翻译都用它。
    @Published var selection = ""
    /// 讲解页全选后的范围。朗读选区用它。
    @Published var explanationSelection = ""
    /// 翻译页全选后的范围。
    @Published var translationSelection = ""
    /// 标题旁的小点。iOS 不另做保存页。
    @Published var dirty = false
    /// 已生成的讲解。空则显示空状态。
    @Published var explanation = ""
    /// 已生成的译文。
    @Published var translation = ""
    /// 当前语言的译文对齐。来自 `.aibook` 或日后写入。
    @Published var translationAlignment: TranslationAlignment?
    /// 当前语言的讲解对齐。
    @Published var explanationAlignment: TranslationAlignment?
    /// 阅读页停在第几页。旋转后由页面夹回合法范围。
    @Published var readingIndex = 0
    /// 重分页时用来回到相近位置（UTF-16 偏移）。
    @Published var readingCharacterAnchor = 0
    /// 各语言已经生成的译文和讲解。键是 BCP-47。
    @Published var languages: [String: IOSLanguageCopy] = [:]
    /// 当前正在看的语言。
    @Published var activeLanguageID = "zh-Hans"
    /// 原文页请求系统导出。口令和菜单共用这一下。
    @Published var exportKind: IOSExportKind?
    /// 菜单请求系统打开。原文、讲解、译文各走各的。
    @Published var importKind: IOSImportKind?
    @Published var libraryPresented = false
    /// 模型地址和密钥都写了，才允许讲解和翻译按钮发请求。
    @Published var modelReady = false

    /// 没有打开文件时，原文页中只放两枚主按钮。
    var hasSource: Bool {
        !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty // 空白不算打开了一本书
    }

    /// 讲解选区按钮：没有选区就不可用。
    var canExplainSelection: Bool {
        modelReady && !selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty // 先回原文选中
    }

    /// 全文讲解：原文为空则不可用。
    var canExplainFull: Bool {
        modelReady && hasSource // 空书不发全文
    }

    /// 新建原文。清掉这一本，不关窗口。
    func newDocument() {
        title = "" // 回到未打开
        source = ""
        selection = ""
        explanationSelection = ""
        translationSelection = ""
        explanation = ""
        translation = ""
        translationAlignment = nil
        explanationAlignment = nil
        languages = [:] // 各语言稿一起清
        readingIndex = 0
        readingCharacterAnchor = 0
        dirty = false
    }

    /// 只清当前语言的讲解。原文留着。
    func clearExplanation() {
        explanationSelection = ""
        storeExplanation("")
    }

    /// 只清当前语言的译文。
    func clearTranslation() {
        translationSelection = ""
        storeTranslation("")
    }

    /// 打开一份纯文本，停在原文页的数据上。
    func openText(name: String, text: String) {
        title = name // 导航标题用文件名
        source = text // 正文可继续编辑
        selection = "" // 新文件不沿用上一次选区
        explanationSelection = ""
        translationSelection = ""
        explanation = "" // 另一本书的讲解不留在这一页
        translation = ""
        translationAlignment = nil
        explanationAlignment = nil
        readingIndex = 0 // 新书从第一页读
        readingCharacterAnchor = 0
        languages = [:] // 另一本书的各语言稿不留下
        activeLanguageID = AIBookBundle.contentLanguageID(appLanguage: BookL10n.currentLanguage)
        dirty = false // 刚打开的文件还没改
        restoreReadingAnchor()
    }

    /// 打开 `.aibook`：原文和各语言译文、讲解一起回来，仍停在原文。
    func openBundle(_ bundle: AIBookBundle) {
        title = bundle.title
        source = bundle.source
        selection = ""
        explanationSelection = ""
        translationSelection = ""
        languages = bundle.languages.mapValues { payload in
            IOSLanguageCopy(
                translation: payload.translationText ?? "",
                explanation: payload.explanationText ?? "",
                translationAlignment: payload.translationAlignment,
                explanationAlignment: payload.explanationAlignment
            )
        }
        let preferred = AIBookBundle.contentLanguageID(appLanguage: BookL10n.currentLanguage)
        activeLanguageID = languages[preferred] == nil ? (languages.keys.sorted().first ?? preferred) : preferred
        showActiveLanguage()
        readingIndex = 0
        readingCharacterAnchor = 0
        dirty = false
        restoreReadingAnchor()
    }

    /// 把当前译文和讲解收成可以写成 `.aibook` 的包。
    func makeBundle() -> AIBookBundle {
        var bundle = AIBookBundle(title: title.isEmpty ? "AIBook" : title, source: source, languages: [:])
        var copies = languages
        var current = copies[activeLanguageID] ?? IOSLanguageCopy()
        current.translation = translation
        current.explanation = explanation
        copies[activeLanguageID] = current
        for (id, copy) in copies where !copy.translation.isEmpty || !copy.explanation.isEmpty {
            bundle.upsert(
                languageID: id,
                translationText: copy.translation.isEmpty ? nil : copy.translation,
                translationAlignment: copy.translationAlignment,
                replaceTranslationAlignment: copy.translationAlignment != nil,
                explanationText: copy.explanation.isEmpty ? nil : copy.explanation,
                explanationAlignment: copy.explanationAlignment,
                replaceExplanationAlignment: copy.explanationAlignment != nil
            )
        }
        return bundle
    }

    /// 切换已生成的语言，只改显示。
    func selectLanguage(_ id: String) {
        rememberActiveCopy()
        activeLanguageID = id
        showActiveLanguage()
    }

    /// 追问结果接到讲解末尾，不覆盖上一段。
    func appendExplanation(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            storeExplanation(trimmed)
        } else {
            storeExplanation(explanation + "\n\n" + trimmed)
        }
    }

    /// 讲解写回当前语言。
    func storeExplanation(_ text: String) {
        explanation = text
        var copy = languages[activeLanguageID] ?? IOSLanguageCopy()
        copy.explanation = text
        if var alignment = copy.explanationAlignment {
            alignment.isStale = true
            copy.explanationAlignment = alignment
        }
        explanationAlignment = copy.explanationAlignment
        languages[activeLanguageID] = copy
    }

    /// 按对照行拼回译文或讲解全文。
    func storeCompanionLines(_ lines: [String], explanation: Bool) {
        let joined = lines.joined(separator: "\n")
        if explanation {
            storeExplanation(joined)
        } else {
            storeTranslation(joined)
        }
    }

    func updateCompanionPair(at index: Int, pairs: [(source: String, other: String)], newOther: String, explanation: Bool) {
        guard pairs.indices.contains(index) else { return }
        var updated = pairs
        var pair = updated[index]
        pair.other = newOther
        updated[index] = pair
        storeCompanionLines(updated.map(\.other), explanation: explanation)
    }

    /// 点对照段回原文时写入选区。
    func selectSourcePair(at index: Int, in pairs: [(source: String, other: String)]) {
        guard pairs.indices.contains(index) else { return }
        let text = pairs[index].source
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        selection = text
    }

    /// 译文写回当前语言。
    func storeTranslation(_ text: String) {
        translation = text
        var copy = languages[activeLanguageID] ?? IOSLanguageCopy()
        copy.translation = text
        if var alignment = copy.translationAlignment {
            alignment.isStale = true
            copy.translationAlignment = alignment
        }
        translationAlignment = copy.translationAlignment
        languages[activeLanguageID] = copy
    }

    /// 已经有讲解正文的语言，给页顶分段用。
    var explanationLanguageIDs: [String] {
        languages.filter { !$0.value.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .keys.sorted()
    }

    /// 已经有译文的语言。
    var translationLanguageIDs: [String] {
        languages.filter { !$0.value.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .keys.sorted()
    }

    /// 记住这本书读到第几页。
    func rememberReading(pageIndex: Int? = nil, characterAnchor: Int? = nil) {
        guard !title.isEmpty else { return }
        if let pageIndex { readingIndex = pageIndex }
        if let characterAnchor { readingCharacterAnchor = characterAnchor }
        UserDefaults.standard.set(readingIndex, forKey: readingKey)
        UserDefaults.standard.set(readingCharacterAnchor, forKey: readingAnchorKey)
    }

    /// 用户改了原文。内容和上次一样时不刷新，避免编辑器失焦。
    func editSource(_ text: String) {
        guard text != source else { return } // 选区变化也会走到这里时不要重绘
        source = text // 编辑器回写
        dirty = true // 标题旁显示未保存
        markAlignmentsStaleAfterSourceEdit()
    }

    func setTranslationAlignmentLocked(_ locked: Bool) {
        guard var alignment = translationAlignment else { return }
        alignment.isLocked = locked
        translationAlignment = alignment
        var copy = languages[activeLanguageID] ?? IOSLanguageCopy()
        copy.translationAlignment = alignment
        languages[activeLanguageID] = copy
    }

    func setExplanationAlignmentLocked(_ locked: Bool) {
        guard var alignment = explanationAlignment else { return }
        alignment.isLocked = locked
        explanationAlignment = alignment
        var copy = languages[activeLanguageID] ?? IOSLanguageCopy()
        copy.explanationAlignment = alignment
        languages[activeLanguageID] = copy
    }

    /// 按当前原文与译文重新分段对齐。锁定或缺正文时不改。
    func alignTranslationToSource() {
        guard !(translationAlignment?.isLocked ?? false) else { return }
        guard let alignment = IOSAlignmentSync.alignParagraphs(source: source, companion: translation) else { return }
        translationAlignment = alignment
        var copy = languages[activeLanguageID] ?? IOSLanguageCopy()
        copy.translationAlignment = alignment
        languages[activeLanguageID] = copy
    }

    func alignExplanationToSource() {
        guard !(explanationAlignment?.isLocked ?? false) else { return }
        guard let alignment = IOSAlignmentSync.alignParagraphs(source: source, companion: explanation) else { return }
        explanationAlignment = alignment
        var copy = languages[activeLanguageID] ?? IOSLanguageCopy()
        copy.explanationAlignment = alignment
        languages[activeLanguageID] = copy
    }

    private func markAlignmentsStaleAfterSourceEdit() {
        if var alignment = translationAlignment, !alignment.isLocked {
            alignment.isStale = true
            translationAlignment = alignment
        }
        if var alignment = explanationAlignment, !alignment.isLocked {
            alignment.isStale = true
            explanationAlignment = alignment
        }
        for id in languages.keys {
            var copy = languages[id] ?? IOSLanguageCopy()
            if var alignment = copy.translationAlignment, !alignment.isLocked {
                alignment.isStale = true
                copy.translationAlignment = alignment
            }
            if var alignment = copy.explanationAlignment, !alignment.isLocked {
                alignment.isStale = true
                copy.explanationAlignment = alignment
            }
            languages[id] = copy
        }
    }

    /// 名著补充写回。有选区只换那一段，否则换整页。
    func applySupplement(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let selected = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selected.isEmpty, let range = source.range(of: selected) {
            source.replaceSubrange(range, with: cleaned) // 只替换选中的节选
            selection = cleaned
        } else {
            source = cleaned // 没有选区就换成补全后的全文
            selection = ""
        }
        dirty = true
    }

    /// 导出文件名。讲解和译文带上种类，避免盖住原文。
    func exportFilename() -> String {
        let base = title.isEmpty ? "AIBook" : title // 没书名时用应用名
        switch exportKind {
        case .aibook:
            return base + ".aibook"
        case .selection:
            return base + "-selection"
        case .explanation:
            return base + "-explanation"
        case .translation:
            return base + "-translation"
        case .text, .saveAs, nil:
            return base
        }
    }

    /// 导出字节。`.aibook` 是包，其余是 UTF-8。
    func exportData() -> Data {
        switch exportKind {
        case .aibook:
            return (try? makeBundle().encoded()) ?? Data(source.utf8) // 打包失败就退回原文
        case .selection:
            return Data(selection.utf8)
        case .explanation:
            return Data(explanation.utf8)
        case .translation:
            return Data(translation.utf8)
        case .text, .saveAs, nil:
            return Data(source.utf8)
        }
    }

    /// 每本书单独记阅读页。
    private var readingKey: String { "aiBook.ios.page." + title }
    private var readingAnchorKey: String { "aiBook.ios.anchor." + title }

    /// 打开时回到上次的阅读位置。
    private func restoreReadingAnchor() {
        readingIndex = UserDefaults.standard.integer(forKey: readingKey)
        readingCharacterAnchor = UserDefaults.standard.integer(forKey: readingAnchorKey)
    }

    /// 切语言前先把屏幕上的稿收进表。
    private func rememberActiveCopy() {
        var copy = languages[activeLanguageID] ?? IOSLanguageCopy()
        copy.translation = translation
        copy.explanation = explanation
        copy.translationAlignment = translationAlignment
        copy.explanationAlignment = explanationAlignment
        if !copy.translation.isEmpty || !copy.explanation.isEmpty
            || copy.translationAlignment != nil || copy.explanationAlignment != nil {
            languages[activeLanguageID] = copy
        }
    }

    /// 把选中语言的稿铺到页面上。
    private func showActiveLanguage() {
        let copy = languages[activeLanguageID] ?? IOSLanguageCopy()
        translation = copy.translation
        explanation = copy.explanation
        translationAlignment = copy.translationAlignment
        explanationAlignment = copy.explanationAlignment
    }
}

/// 一种语言里已经生成的译文和讲解。某一侧可以是空的。
struct IOSLanguageCopy: Equatable {
    var translation = ""
    var explanation = ""
    var translationAlignment: TranslationAlignment?
    var explanationAlignment: TranslationAlignment?
}

/// 要交给系统导出的种类。讲解和译文不把原文标成已保存。
enum IOSExportKind: Equatable {
    case text
    case saveAs
    case aibook
    case selection
    case explanation
    case translation

    /// 这次导出成功后，原文的未保存点可以去掉。
    var clearsSourceDirty: Bool {
        switch self {
        case .text, .saveAs, .aibook:
            return true
        case .selection, .explanation, .translation:
            return false
        }
    }
}

/// 系统文件选择器要写回哪一页。打开文件和打开目录分开，避免目录选择器把返回卡住。
enum IOSImportKind: Equatable {
    case book
    case directory
    case explanation
    case translation
}

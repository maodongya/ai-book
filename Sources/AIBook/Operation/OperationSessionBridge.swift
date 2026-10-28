import Foundation

/// 把操作接到现有会话方法。快照和执行都不另写讲解或翻译。
@MainActor
enum OperationSessionBridge {
    /// 发给模型的短快照。
    static func snapshot(viewModel: ReadingViewModel, paneFocus: LearningPaneFocus) -> OperationContextSnapshot {
        let document = viewModel.document
        let settings = AppSettings.shared
        return OperationContextSnapshot.make(
            fileName: document.currentFileURL?.lastPathComponent ?? document.fileName, // 不带未保存圆点
            hasDocumentPath: document.currentFileURL != nil,
            isDirty: document.isDirty,
            selection: viewModel.effectiveSelectedText,
            experienceMode: viewModel.mode.experienceMode,
            paneFocus: paneFocus,
            rightPage: viewModel.rightPageTab,
            assistantPanel: viewModel.assistant.readingAssistantPanel,
            explanationLanguage: document.explanationBundle.displayed,
            translationLanguage: document.displayedTranslationLanguage,
            enabledExplanationLanguages: settings.explanationTargetLanguages,
            enabledTranslationLanguages: settings.translationTargetLanguages,
            speech: speechState(of: viewModel),
            isRunning: viewModel.isRunning,
            libraryFileNames: libraryFileNames(in: document.directoryBrowserSessions)
        )
    }

    /// 执行时再读一次界面，避免听写期间状态过期。
    static func runtimeState(viewModel: ReadingViewModel) -> OperationRuntimeState {
        let document = viewModel.document
        let settings = AppSettings.shared
        return OperationRuntimeState(
            hasSelection: !viewModel.effectiveSelectedText.isEmpty,
            hasBody: !viewModel.fileContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            isRunning: viewModel.isRunning,
            speech: speechState(of: viewModel),
            enabledExplanationLanguages: Set(settings.explanationTargetLanguages),
            enabledTranslationLanguages: Set(settings.translationTargetLanguages),
            explanationContentLanguages: contentLanguages(in: document.bundledLanguages, explanation: true),
            translationContentLanguages: contentLanguages(in: document.bundledLanguages, explanation: false),
            libraryFileNames: libraryFileNames(in: document.directoryBrowserSessions)
        )
    }

    /// 调用目录里写明的现有方法。
    static func perform(
        _ action: OperationAction,
        viewModel: ReadingViewModel,
        setPaneFocus: (LearningPaneFocus) -> Void,
        toggleReadingMode: () -> Void
    ) {
        switch action {
        case .explainSelection:
            viewModel.assistant.explainSelection()
        case .explainFullText:
            viewModel.assistant.explainFullText()
        case .translateWordByWord:
            viewModel.generateLessonPlan()
        case .translateParagraph:
            viewModel.refineLessonPlan()
        case .readOriginalSelection:
            viewModel.assistant.readOriginalSelectionAloud()
        case .readOriginalFull:
            viewModel.assistant.readOriginalFullTextAloud()
        case .readTranslationSelection:
            viewModel.assistant.readTranslationSelectionAloud()
        case .readTranslationFull:
            viewModel.assistant.readTranslationFullTextAloud()
        case .readExplanationSelection:
            viewModel.assistant.readExplanationSelectionAloud()
        case .readExplanationFull:
            viewModel.assistant.readExplanationFullTextAloud()
        case .pauseSpeech, .resumeSpeech:
            viewModel.assistant.toggleExplanationSpeechPause()
        case .stopSpeech:
            viewModel.assistant.stopExplanationSpeech()
        case .stopCurrentRun:
            viewModel.stopCurrentRun()
        case .toggleReadingMode:
            toggleReadingMode()
        case .setPaneFocus(let raw):
            if let focus = LearningPaneFocus(rawValue: raw) {
                setPaneFocus(focus) // 焦点在界面 State 上
            }
        case .showAssistantPanel(let raw):
            guard let panel = ReadingAssistantPanel(rawValue: raw) else { return }
            viewModel.selectRightPageTab(.readingAssistant)
            viewModel.assistant.selectReadingAssistantPanel(panel)
        case .showRightPage(let page):
            viewModel.selectRightPageTab(page == "evolution" ? .aiEvolution : .readingAssistant)
        case .showExplanationLanguage(let raw):
            guard let language = TranslationTargetLanguage(rawValue: raw) else { return }
            viewModel.document.explanationBundle.show(language)
        case .showTranslationLanguage(let raw):
            guard let language = TranslationTargetLanguage(rawValue: raw) else { return }
            viewModel.document.showTranslationLanguage(language)
        case .openLibraryFile(let name):
            guard let url = libraryURL(matching: name, sessions: viewModel.document.directoryBrowserSessions) else { return }
            viewModel.document.openFileFromDirectory(at: url, target: .original)
        case .openFilePanel:
            viewModel.document.openFile()
        case .openDirectoryPanel:
            viewModel.document.openDirectory()
        case .save:
            viewModel.document.save()
        case .saveAs:
            viewModel.document.saveAs()
        case .saveSelectionAs:
            viewModel.document.saveSelectionAs()
        case .saveAsAIBook:
            viewModel.document.saveAsAIBook()
        case .selectAllLeft:
            viewModel.document.selectAllLeftPage()
        case .selectAllRight:
            viewModel.document.selectAllRightPage()
        case .supplementClassic:
            viewModel.assistant.supplementClassicLiterature()
        case .startEvolution:
            viewModel.evolution.startEvolution()
        case .analyzeOptimizations:
            viewModel.evolution.analyzeOptimizations()
        }
    }

    /// 朗读三态。
    private static func speechState(of viewModel: ReadingViewModel) -> OperationSpeechState {
        if viewModel.assistant.isExplanationSpeechPaused { return .paused }
        if viewModel.assistant.isSpeakingExplanation { return .speaking }
        return .idle
    }

    /// 语言包里已经有讲解或译文的语言。
    private static func contentLanguages(
        in bundled: [String: AIBookLanguagePayload],
        explanation: Bool
    ) -> Set<TranslationTargetLanguage> {
        var languages: Set<TranslationTargetLanguage> = []
        for (id, payload) in bundled {
            guard let language = TranslationTargetLanguage(rawValue: id) else { continue }
            let hasContent = explanation ? payload.hasExplanation : payload.hasTranslation
            if hasContent {
                languages.insert(language)
            }
        }
        return languages
    }

    /// 书库树里的文件名，同名文件都保留。
    private static func libraryFileNames(in sessions: [DirectoryBrowserRootSession]) -> [String] {
        sessions.flatMap { session -> [String] in
            guard let tree = session.tree else { return [] }
            return names(in: tree)
        }
    }

    /// 深度优先收集文件名。
    private static func names(in node: DirectoryTreeNode) -> [String] {
        if node.isDirectory {
            return (node.children ?? []).flatMap { names(in: $0) }
        }
        return [node.name]
    }

    /// 文件名唯一时返回那个 URL。
    private static func libraryURL(matching name: String, sessions: [DirectoryBrowserRootSession]) -> URL? {
        var matches: [URL] = []
        for session in sessions {
            guard let tree = session.tree else { continue }
            collect(name: name, node: tree, into: &matches)
        }
        return matches.count == 1 ? matches[0] : nil
    }

    /// 大小写不敏感地收集同名文件。
    private static func collect(name: String, node: DirectoryTreeNode, into matches: inout [URL]) {
        if node.isDirectory {
            for child in node.children ?? [] {
                collect(name: name, node: child, into: &matches)
            }
            return
        }
        if node.name.caseInsensitiveCompare(name) == .orderedSame {
            matches.append(node.url)
        }
    }
}

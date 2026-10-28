import Foundation

/// 按目录执行计划：先挡未启用语言，再检查前提，确认后才调用原功能。
enum OperationExecutor {
    /// confirm 返回 false 时，当前步和后面的步骤都不调用。
    static func execute(
        plan: OperationPlan,
        state: OperationRuntimeState,
        confirm: (OperationAction) async -> Bool,
        perform: (OperationAction) -> Void
    ) async -> OperationExecutionLog {
        let gated = applyLanguageGate(actions: plan.actions, state: state) // 未启用语言整段去掉讲解和翻译
        var log = OperationExecutionLog(skipped: gated.skipped)
        for action in gated.kept {
            if state.isRunning, !allowedWhileRunning(action) { // 生成中只留停止和朗读控制
                log.skipped.append(OperationSkip(action: action, reason: .busy))
                continue
            }
            if action.requiresConfirmation {
                let accepted = await confirm(action) // 界面弹出确认
                if !accepted {
                    return log // 取消后后面的步骤也不做
                }
            }
            if let reason = skipReason(for: action, state: state) {
                log.skipped.append(OperationSkip(action: action, reason: reason))
                continue
            }
            let resolved = resolve(action, state: state) // 书库查询换成唯一文件名
            switch resolved {
            case .skip(let reason):
                log.skipped.append(OperationSkip(action: action, reason: reason))
            case .ready(let action):
                perform(action) // 调用现有功能
            }
        }
        return log
    }

    /// 计划里出现未启用语言的切换时，丢掉讲解、翻译和全部切语言。
    private static func applyLanguageGate(
        actions: [OperationAction],
        state: OperationRuntimeState
    ) -> (kept: [OperationAction], skipped: [OperationSkip]) {
        let blocked = actions.contains { action in
            switch action {
            case .showExplanationLanguage(let language):
                return !enabled(language, in: state.enabledExplanationLanguages)
            case .showTranslationLanguage(let language):
                return !enabled(language, in: state.enabledTranslationLanguages)
            default:
                return false
            }
        }
        guard blocked else { return (actions, []) } // 语言都在勾选里，原样执行
        var kept: [OperationAction] = []
        var skipped: [OperationSkip] = []
        for action in actions {
            if isLanguageBound(action) {
                skipped.append(OperationSkip(action: action, reason: .languageNotEnabled))
            } else {
                kept.append(action) // 朗读、打开、保存仍继续
            }
        }
        return (kept, skipped)
    }

    /// 讲解、翻译和两种切语言绑在同一句的语言要求上。
    private static func isLanguageBound(_ action: OperationAction) -> Bool {
        switch action {
        case .explainSelection, .explainFullText, .translateWordByWord, .translateParagraph,
             .showExplanationLanguage, .showTranslationLanguage:
            return true
        default:
            return false
        }
    }

    /// 生成进行中仍允许停掉生成和朗读。
    private static func allowedWhileRunning(_ action: OperationAction) -> Bool {
        switch action {
        case .stopCurrentRun, .pauseSpeech, .resumeSpeech, .stopSpeech:
            return true
        default:
            return false
        }
    }

    /// 前提不满足就给出原因。书库匹配另走 resolve。
    private static func skipReason(for action: OperationAction, state: OperationRuntimeState) -> OperationSkipReason? {
        switch action {
        case .explainSelection, .readOriginalSelection, .readTranslationSelection, .readExplanationSelection, .saveSelectionAs:
            return state.hasSelection ? nil : .noSelection
        case .explainFullText, .translateWordByWord, .translateParagraph, .readOriginalFull, .readTranslationFull,
             .readExplanationFull, .supplementClassic:
            return state.hasBody ? nil : .emptyBody
        case .pauseSpeech:
            return state.speech == .speaking ? nil : .speechNotActive
        case .resumeSpeech:
            return state.speech == .paused ? nil : .speechNotPaused
        case .stopSpeech:
            return state.speech == .idle ? .speechNotActive : nil
        case .showExplanationLanguage(let language):
            guard enabled(language, in: state.enabledExplanationLanguages) else { return .languageNotEnabled }
            return enabled(language, in: state.explanationContentLanguages) ? nil : .languageContentMissing
        case .showTranslationLanguage(let language):
            guard enabled(language, in: state.enabledTranslationLanguages) else { return .languageNotEnabled }
            return enabled(language, in: state.translationContentLanguages) ? nil : .languageContentMissing
        default:
            return nil // 没有额外前提
        }
    }

    /// 书库查询换成唯一文件名。其它操作原样通过。
    private static func resolve(_ action: OperationAction, state: OperationRuntimeState) -> Resolve {
        guard case .openLibraryFile(let query) = action else { return .ready(action) }
        switch OperationLibraryMatch.uniqueName(query: query, fileNames: state.libraryFileNames) {
        case .unique(let name):
            return .ready(.openLibraryFile(name)) // 用名单里的文件名，避免大小写不一致
        case .skipped(let reason):
            return .skip(reason)
        }
    }

    /// rawValue 对上勾选集合才算启用。
    private static func enabled(_ language: String, in set: Set<TranslationTargetLanguage>) -> Bool {
        set.contains { $0.rawValue == language }
    }

    private enum Resolve {
        case ready(OperationAction)
        case skip(OperationSkipReason)
    }
}

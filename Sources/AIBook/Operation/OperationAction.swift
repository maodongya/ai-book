import Foundation

/// 听写状态。执行器用它判断暂停、继续和停止能不能做。
enum OperationSpeechState: String, Equatable {
    case idle // 没在读
    case speaking // 正在读
    case paused // 已暂停
}

/// 目录里的一步操作。参数只保留目录允许的值。
enum OperationAction: Equatable {
    case explainSelection
    case explainFullText
    case translateWordByWord
    case translateParagraph
    case readOriginalSelection
    case readOriginalFull
    case readTranslationSelection
    case readTranslationFull
    case readExplanationSelection
    case readExplanationFull
    case pauseSpeech
    case resumeSpeech
    case stopSpeech
    case stopCurrentRun
    case toggleReadingMode
    case setPaneFocus(String) // both / leading / trailing
    case showAssistantPanel(String) // explanation / translation
    case showRightPage(String) // assistant / evolution
    case showExplanationLanguage(String) // 语言 rawValue
    case showTranslationLanguage(String)
    case openLibraryFile(String) // 书库文件名
    case openFilePanel
    case openDirectoryPanel
    case save
    case saveAs
    case saveSelectionAs
    case saveAsAIBook
    case selectAllLeft
    case selectAllRight
    case supplementClassic
    case startEvolution
    case analyzeOptimizations

    /// 进化和分析先问过用户才执行。
    var requiresConfirmation: Bool {
        switch self {
        case .startEvolution, .analyzeOptimizations: // 会改工程或排队
            return true
        default:
            return false // 其余安全操作马上做
        }
    }
}

/// 一轮解析得到的操作，顺序就是执行顺序。
struct OperationPlan: Equatable {
    var actions: [OperationAction] // 空表示没有对应操作
}

/// 某一步没执行的原因。界面再换成文案。
enum OperationSkipReason: Equatable {
    case noSelection
    case emptyBody
    case languageNotEnabled
    case languageContentMissing
    case libraryNoMatch
    case libraryMultipleMatches
    case speechNotActive
    case speechNotPaused
    case busy
}

/// 被跳过的一步，测试和状态行都看它。
struct OperationSkip: Equatable {
    var action: OperationAction
    var reason: OperationSkipReason
}

/// 一次执行留下的跳过记录。真正调用的操作由 perform 收集。
struct OperationExecutionLog: Equatable {
    var skipped: [OperationSkip] = [] // 按原顺序
}

/// 执行那一刻的界面事实。不放全文。
struct OperationRuntimeState: Equatable {
    var hasSelection: Bool = false
    var hasBody: Bool = false
    var isRunning: Bool = false
    var speech: OperationSpeechState = .idle
    var enabledExplanationLanguages: Set<TranslationTargetLanguage> = []
    var enabledTranslationLanguages: Set<TranslationTargetLanguage> = []
    var explanationContentLanguages: Set<TranslationTargetLanguage> = []
    var translationContentLanguages: Set<TranslationTargetLanguage> = []
    var libraryFileNames: [String] = []
}

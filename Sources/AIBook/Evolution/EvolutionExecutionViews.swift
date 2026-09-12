import AIBookEvolution
import AppKit
import SwiftUI

/// AI 进化页顶栏：Cursor 模型、队列与状态（单面板，无子 Tab）。
struct EvolutionUtilityTabsPanel: View {
    @ObservedObject private var settings = AppSettings.shared

    let items: [OptimizationItem]
    let projectPath: String
    let isRunning: Bool
    let isAnalyzing: Bool
    let executingCommandNumber: Int?
    let budget: ModelTokenBudget
    let liveToolLabel: String?
    let lastRequestId: String?
    let hasPending: Bool
    let onAddUserItem: (String) -> Void
    let onSkip: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onPin: (UUID) -> Void
    let onRestore: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            compactControlBar
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()
                .overlay(BookTheme.pageEdge.opacity(0.65))

            EvolutionCommandQueuePanel(
                items: items,
                projectPath: projectPath,
                isRunning: isRunning,
                isAnalyzing: isAnalyzing,
                executingCommandNumber: executingCommandNumber,
                embeddedInTabs: true,
                onAddUserItem: onAddUserItem,
                onSkip: onSkip,
                onDelete: onDelete,
                onPin: onPin,
                onRestore: onRestore
            )
        }
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.42))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(BookTheme.pageEdge.opacity(0.75), lineWidth: 1)
                }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .onAppear {
            if settings.explanationSource != .cursor {
                settings.explanationSource = .cursor
            }
        }
    }

    private var compactControlBar: some View {
        HStack(spacing: 12) {
            EvolutionCursorModelRow()

            Toggle(isOn: $settings.autoEvolutionEnabled) {
                Text(BookL10n.string("settings.autoUpgrade"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkSecondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .disabled(isRunning)

            Spacer(minLength: 8)

            statusTrailing
        }
    }

    @ViewBuilder
    private var statusTrailing: some View {
        if budget.isOverLimit {
            Label(BookL10n.string("evolution.tokenExceeded"), systemImage: "exclamationmark.triangle.fill")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.vermilion)
        } else if isRunning {
            if isAnalyzing {
                Label(BookL10n.string("evolution.analyzing"), systemImage: "magnifyingglass")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)
            } else if let number = executingCommandNumber {
                Label("#\(number)", systemImage: "play.circle.fill")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)
            } else if let liveToolLabel {
                Label(liveToolLabel, systemImage: "gearshape.2")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)
                    .lineLimit(1)
            }
        } else if let lastRequestId, !lastRequestId.isEmpty {
            Text("Run \(lastRequestId.prefix(8))")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
                .lineLimit(1)
        } else if !items.isEmpty {
            let completed = items.filter { $0.status == .completed }.count
            Text(BookL10n.format("evolution.queue.simple", completed, items.count))
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
        } else if hasPending {
            Text(BookL10n.string("evolution.hasPending"))
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)
        }
    }
}

/// 进化页 Cursor 模型选择（暂仅支持 Cursor）。
struct EvolutionCursorModelRow: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var catalog = CursorModelCatalog.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "cursorarrow.rays")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(BookTheme.leather)
            Picker(BookL10n.string("cursor.modelPicker"), selection: cursorModelBinding) {
                if catalog.models.isEmpty {
                    ForEach(CursorModelOption.allCases) { model in
                        Text(model.label).tag(model.rawValue)
                    }
                } else {
                    ForEach(catalog.models) { model in
                        Text(model.label).tag(model.id)
                    }
                }
            }
            .labelsHidden()
            .frame(maxWidth: 180)

            if settings.isCursorRunnable {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(BookTheme.jade)
                    .help(BookL10n.string("cursor.ready"))
            } else {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .help(BookL10n.string("cursor.evolutionKeyHelp"))
            }
        }
        .task {
            await catalog.refresh()
        }
    }

    private var cursorModelBinding: Binding<String> {
        Binding(
            get: { settings.resolvedCursorModel },
            set: { settings.cursorModel = $0 }
        )
    }
}

/// AI 进化页顶栏：优化队列与源码路径摘要。
struct EvolutionCommandQueuePanel: View {
    let items: [OptimizationItem]
    let projectPath: String
    let isRunning: Bool
    var isAnalyzing: Bool = false
    var executingCommandNumber: Int?
    var embeddedInTabs: Bool = false
    var onAddUserItem: ((String) -> Void)?
    var onSkip: ((UUID) -> Void)?
    var onDelete: ((UUID) -> Void)?
    var onPin: ((UUID) -> Void)?
    var onRestore: ((UUID) -> Void)?

    @State private var draftTitle = ""

    private var sortedItems: [OptimizationItem] {
        items.sorted { $0.number < $1.number }
    }

    private var pendingItems: [OptimizationItem] {
        items.filter { $0.status == .pending }
    }

    private var completedCount: Int {
        items.filter { $0.status == .completed }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if embeddedInTabs, !items.isEmpty {
                HStack {
                    Text(BookL10n.format("evolution.completedFraction", completedCount, items.count))
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                    Spacer()
                    if isAnalyzing, isRunning {
                        Label(BookL10n.string("evolution.analyzing"), systemImage: "magnifyingglass")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.leather)
                    } else if isRunning, let executingCommandNumber {
                        Label(BookL10n.format("evolution.executing", executingCommandNumber), systemImage: "play.circle.fill")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.leather)
                    }
                }
            }

            if items.isEmpty {
                Text(BookL10n.string("composer.analyzeHint"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(sortedItems) { item in
                            queueRow(item)
                        }
                    }
                }
                .frame(maxHeight: 180)

                if let next = pendingItems.sorted(by: { $0.number < $1.number }).first {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: isRunning && executingCommandNumber == next.number
                            ? "play.circle.fill"
                            : "arrow.right.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(BookTheme.leather)
                        Text(BookL10n.format("evolution.nextItem", next.title))
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.inkSecondary)
                            .lineLimit(2)
                    }
                }
            }

            if onAddUserItem != nil {
                HStack(spacing: 6) {
                    TextField(BookL10n.string("evolution.draft.placeholder"), text: $draftTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(BookTheme.captionFont)
                    Button(BookL10n.string("action.add")) {
                        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !title.isEmpty else { return }
                        onAddUserItem?(title)
                        draftTitle = ""
                    }
                    .font(BookTheme.captionFont)
                    .disabled(isRunning || draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(BookTheme.inkMuted)
                Text(projectPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(BookTheme.inkSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(12)
        .modifier(EvolutionPanelChromeModifier(embeddedInTabs: embeddedInTabs))
    }

    @ViewBuilder
    private func queueRow(_ item: OptimizationItem) -> some View {
        let isExecuting = isRunning && executingCommandNumber == item.number
        let isNext = item.status == .pending && item.number == pendingItems.sorted(by: { $0.number < $1.number }).first?.number

        HStack(alignment: .top, spacing: 8) {
            Image(systemName: statusIcon(for: item, isExecuting: isExecuting, isNext: isNext))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(statusColor(for: item, isExecuting: isExecuting, isNext: isNext))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("#\(item.number)")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.leather)
                    Text(item.title)
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkSecondary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Text(item.source == .ai ? BookL10n.string("evolution.source.ai") : BookL10n.string("evolution.source.manual"))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(BookTheme.inkMuted)
                }
                HStack(spacing: 6) {
                    Text(statusLabel(for: item))
                        .font(.system(size: 9))
                        .foregroundStyle(BookTheme.inkMuted)
                    Text(item.category.rawValue)
                        .font(.system(size: 9))
                        .foregroundStyle(BookTheme.inkMuted)
                    if item.priority == .high {
                        Text(BookL10n.string("evolution.highPriority"))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(BookTheme.vermilion)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowBackground(for: item, isExecuting: isExecuting, isNext: isNext))
        }
        .contextMenu {
            if item.status == .pending {
                if let onPin {
                    Button(BookL10n.string("action.pin")) { onPin(item.id) }
                }
                if let onSkip {
                    Button(BookL10n.string("action.skip")) { onSkip(item.id) }
                }
                if let onDelete {
                    Button(BookL10n.string("action.delete"), role: .destructive) { onDelete(item.id) }
                }
            } else if item.status == .skipped {
                if let onRestore {
                    Button(BookL10n.string("action.restore")) { onRestore(item.id) }
                }
                if let onDelete {
                    Button(BookL10n.string("action.delete"), role: .destructive) { onDelete(item.id) }
                }
            }
        }
    }

    private func statusIcon(for item: OptimizationItem, isExecuting: Bool, isNext: Bool) -> String {
        switch item.status {
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "minus.circle"
        case .running, .pending:
            if isExecuting { return "play.circle.fill" }
            if isNext { return "arrow.right.circle.fill" }
            return "circle"
        }
    }

    private func statusColor(for item: OptimizationItem, isExecuting: Bool, isNext: Bool) -> Color {
        switch item.status {
        case .completed: return BookTheme.jade
        case .skipped: return BookTheme.inkMuted
        case .running, .pending:
            if isExecuting || isNext { return BookTheme.leather }
            return BookTheme.inkMuted
        }
    }

    private func statusLabel(for item: OptimizationItem) -> String {
        switch item.status {
        case .pending: return BookL10n.string("evolution.status.pending")
        case .running: return BookL10n.string("evolution.status.running")
        case .completed: return BookL10n.string("evolution.status.completed")
        case .skipped: return BookL10n.string("evolution.status.skipped")
        }
    }

    private func rowBackground(for item: OptimizationItem, isExecuting: Bool, isNext: Bool) -> Color {
        if isExecuting { return BookTheme.gold.opacity(0.34) }
        if isNext { return BookTheme.gold.opacity(0.22) }
        return Color.white.opacity(item.status == .completed ? 0.55 : 0.35)
    }
}

/// Cursor Agent 风格：单条回复内可折叠的「思考 + 工具时间线」整体执行轨迹。
struct AssistantExecutionTraceCard: View {
    let thinking: String?
    let toolSteps: [ExecutionStep]?
    var isLive: Bool = false
    var defaultExpanded: Bool = false

    @State private var isExpanded: Bool

    init(
        thinking: String?,
        toolSteps: [ExecutionStep]?,
        isLive: Bool = false,
        defaultExpanded: Bool = false
    ) {
        self.thinking = thinking
        self.toolSteps = toolSteps
        self.isLive = isLive
        self.defaultExpanded = defaultExpanded
        _isExpanded = State(initialValue: defaultExpanded || isLive)
    }

    private var trimmedThinking: String {
        thinking?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var steps: [ExecutionStep] {
        toolSteps ?? []
    }

    private var hasTrace: Bool {
        !trimmedThinking.isEmpty || !steps.isEmpty
    }

    private var completedToolCount: Int {
        steps.filter { $0.status == .completed }.count
    }

    var body: some View {
        if hasTrace {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "timeline.selection")
                            .font(.system(size: 11, weight: .semibold))
                        Text(traceHeaderTitle)
                            .font(BookTheme.captionFont)
                        if isLive {
                            ProgressView().controlSize(.mini)
                        }
                        Spacer()
                        if !steps.isEmpty {
                            Text(traceSummary)
                                .font(BookTheme.captionFont)
                                .foregroundStyle(BookTheme.inkMuted.opacity(0.85))
                        }
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(BookTheme.inkMuted)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    if !trimmedThinking.isEmpty {
                        CollapsibleThinkingBlock(
                            text: trimmedThinking,
                            isLive: isLive && steps.isEmpty,
                            initiallyExpanded: true
                        )
                    }
                    if !steps.isEmpty {
                        ExecutionStepsTimeline(steps: steps, isLive: isLive, nestedInTrace: true)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.28))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(BookTheme.pageEdge.opacity(0.68), lineWidth: 1)
                    }
            }
        }
    }

    private var traceHeaderTitle: String {
        if isLive { return BookL10n.string("evolution.agent.running") }
        return BookL10n.string("evolution.agent.trace")
    }

    private var traceSummary: String {
        if isLive, let last = steps.last {
            let label = EvolutionToolLabels.localizedToolName(last.name)
            if last.status == .running {
                return BookL10n.format("evolution.tools.running", label)
            }
            return BookL10n.format("evolution.tools.progress", completedToolCount, steps.count)
        }
        if steps.contains(where: { $0.status == .failed }) {
            return BookL10n.format("evolution.tools.progressFailed", completedToolCount, steps.count)
        }
        return BookL10n.format("evolution.tools.count", steps.count)
    }
}

/// 面板外框样式（独立展示时使用）。
private struct EvolutionPanelChromeModifier: ViewModifier {
    var embeddedInTabs: Bool
    var accentBorder: Color?

    func body(content: Content) -> some View {
        if embeddedInTabs {
            content
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.42))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder((accentBorder ?? BookTheme.pageEdge.opacity(0.75)), lineWidth: 1)
                        }
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 4)
        }
    }
}

/// 打包安装进度条（进化完成后 build-and-install）。
struct EvolutionRebuildBanner: View {
    let status: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text(BookL10n.string("evolution.autoUpgrading"))
                    .font(BookTheme.labelFont)
                    .foregroundStyle(BookTheme.leather)
                Text(status)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BookTheme.gold.opacity(0.28))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(BookTheme.goldSoft.opacity(0.5), lineWidth: 1)
                }
        }
    }
}

/// Cursor 风格工具调用时间线。
struct ExecutionStepsTimeline: View {
    let steps: [ExecutionStep]
    var isLive: Bool = false
    var nestedInTrace: Bool = false
    @State private var isExpanded = true

    private var completedCount: Int {
        steps.filter { $0.status == .completed }.count
    }

    private var failedCount: Int {
        steps.filter { $0.status == .failed }.count
    }

    var body: some View {
        if nestedInTrace {
            stepsList
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 11, weight: .semibold))
                        Text(headerTitle)
                            .font(BookTheme.captionFont)
                        if isLive {
                            ProgressView().controlSize(.mini)
                        }
                        Spacer()
                        if !isLive, !steps.isEmpty {
                            Text(summaryLabel)
                                .font(BookTheme.captionFont)
                                .foregroundStyle(BookTheme.inkMuted.opacity(0.85))
                        }
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(BookTheme.inkMuted)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    stepsList
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.32))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(BookTheme.pageEdge.opacity(0.65), lineWidth: 1)
                    }
            }
        }
    }

    private var stepsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                ExecutionStepRow(step: step, isLast: index == steps.count - 1)
            }
        }
        .padding(.leading, nestedInTrace ? 0 : 4)
    }

    private var headerTitle: String {
        if isLive { return BookL10n.string("evolution.steps.title") }
        return BookL10n.format("evolution.steps.titleCount", steps.count)
    }

    private var summaryLabel: String {
        if failedCount > 0 {
            return BookL10n.format("evolution.steps.summary", completedCount, failedCount)
        }
        return BookL10n.format("evolution.steps.toolsDone", completedCount)
    }
}

private struct ExecutionStepRow: View {
    let step: ExecutionStep
    let isLast: Bool
    @State private var showsDetail = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                stepStatusIcon(step.status)
                if !isLast {
                    Rectangle()
                        .fill(BookTheme.pageEdge.opacity(0.55))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 14)

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    guard step.hasExpandableDetail else { return }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showsDetail.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: step.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(statusTint)
                        Text(step.displayLabel)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(BookTheme.inkSecondary)
                            .lineLimit(showsDetail ? nil : 2)
                        if step.status == .running {
                            Text(BookL10n.string("evolution.running"))
                                .font(BookTheme.captionFont)
                                .foregroundStyle(BookTheme.leather)
                        } else if let duration = step.durationLabel {
                            Text(duration)
                                .font(BookTheme.captionFont)
                                .foregroundStyle(BookTheme.inkMuted)
                        }
                        Spacer(minLength: 4)
                        if step.hasExpandableDetail {
                            Image(systemName: showsDetail ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(BookTheme.inkMuted)
                        }
                    }
                }
                .buttonStyle(.plain)

                if let detail = step.detail, !detail.isEmpty, !showsDetail {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(BookTheme.inkMuted)
                        .lineLimit(2)
                }

                if showsDetail {
                    stepActionBar

                    if let detail = step.detail, !detail.isEmpty {
                        detailBlock(title: BookL10n.string("evolution.detail.input"), text: detail, tint: BookTheme.leather)
                    }
                    if let result = step.resultSummary, !result.isEmpty {
                        detailBlock(title: BookL10n.string("evolution.detail.result"), text: result, tint: BookTheme.jade)
                    }
                    if let error = step.errorMessage, !error.isEmpty {
                        detailBlock(title: BookL10n.string("evolution.detail.error"), text: error, tint: BookTheme.vermilion)
                    }
                } else if let detail = step.detail, !detail.isEmpty, step.status == .failed {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(BookTheme.inkMuted)
                        .lineLimit(2)
                }
            }
            .padding(.bottom, isLast ? 0 : 10)
        }
        .contextMenu {
            stepContextMenu
        }
    }

    private var statusTint: Color {
        switch step.status {
        case .running: return BookTheme.leather.opacity(0.85)
        case .completed: return BookTheme.jade.opacity(0.9)
        case .failed: return BookTheme.vermilion.opacity(0.9)
        }
    }

    @ViewBuilder
    private var stepActionBar: some View {
        HStack(spacing: 8) {
            if let input = step.inputPreview {
                Button(BookL10n.string("action.copyInput")) {
                    copyToPasteboard(input)
                }
                .buttonStyle(.plain)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)
            }
            if let result = step.resultSummary, !result.isEmpty {
                Button(BookL10n.string("action.copyResult")) {
                    copyToPasteboard(result)
                }
                .buttonStyle(.plain)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.jade)
            }
            if step.hasFileRevealAction, let path = step.resolvedFilePath {
                Button(BookL10n.string("action.revealFinder")) {
                    revealInFinder(path: path)
                }
                .buttonStyle(.plain)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkSecondary)
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var stepContextMenu: some View {
        if let input = step.inputPreview {
            Button(BookL10n.string("action.copyInput")) {
                copyToPasteboard(input)
            }
        }
        if let result = step.resultSummary, !result.isEmpty {
            Button(BookL10n.string("action.copyResult")) {
                copyToPasteboard(result)
            }
        }
        if step.hasFileRevealAction, let path = step.resolvedFilePath {
            Button(BookL10n.string("action.revealFinder")) {
                revealInFinder(path: path)
            }
        }
        if step.hasExpandableDetail {
            Button(showsDetail ? BookL10n.string("evolution.detail.collapse") : BookL10n.string("evolution.detail.expand")) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showsDetail.toggle()
                }
            }
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func revealInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @ViewBuilder
    private func detailBlock(title: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(BookTheme.captionFont)
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(BookTheme.inkSecondary)
                .textSelection(.enabled)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.42))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(tint.opacity(0.25), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private func stepStatusIcon(_ status: ExecutionStep.Status) -> some View {
        switch status {
        case .running:
            ProgressView().controlSize(.mini)
                .frame(width: 14, height: 14)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(BookTheme.jade)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(BookTheme.vermilion)
        }
    }
}

/// 可折叠的思考过程块（Cursor reasoning 风格）。
struct CollapsibleThinkingBlock: View {
    let text: String
    var isLive: Bool = false
    @State private var isExpanded: Bool

    init(text: String, isLive: Bool = false, initiallyExpanded: Bool? = nil) {
        self.text = text
        self.isLive = isLive
        _isExpanded = State(initialValue: initiallyExpanded ?? isLive)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 11, weight: .semibold))
                    Text(isLive ? BookL10n.string("evolution.thinking.live") : BookL10n.string("evolution.thinking"))
                        .font(BookTheme.captionFont)
                    if isLive {
                        ProgressView().controlSize(.mini)
                    }
                    Spacer()
                    Text(BookL10n.format("evolution.thinking.chars", text.count))
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted.opacity(0.8))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(BookTheme.inkMuted)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView {
                    Text(text)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(BookTheme.inkSecondary)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: isLive ? 180 : 260)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.35))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(BookTheme.pageEdge.opacity(0.7), lineWidth: 1)
                        }
                }
            }
        }
    }
}

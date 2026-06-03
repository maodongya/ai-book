import AppKit
import SwiftUI

/// AI 进化页顶栏：左页命令队列与源码路径摘要。
struct EvolutionCommandQueuePanel: View {
    let commands: [EvolutionPlanner.Command]
    let projectPath: String
    let isRunning: Bool
    var executingCommandNumber: Int?

    private var pending: [EvolutionPlanner.Command] {
        commands.filter { !$0.isCompleted }
    }

    private var completed: [EvolutionPlanner.Command] {
        commands.filter(\.isCompleted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("进化队列", systemImage: "list.number")
                    .font(BookTheme.labelFont)
                    .foregroundStyle(BookTheme.leather)

                Spacer()

                if isRunning, let executingCommandNumber {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text("执行 #\(executingCommandNumber)")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.leather)
                    }
                } else if isRunning {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text("执行中")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.leather)
                    }
                }

                if !commands.isEmpty {
                    Text("\(completed.count)/\(commands.count) 已完成")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                }
            }

            if commands.isEmpty {
                Text("左页暂无编号命令。格式示例：29、完善 AI 进化执行过程展示")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                    .lineSpacing(3)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(commands) { command in
                            commandChip(command)
                        }
                    }
                }

                if let next = pending.first {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: isRunning && executingCommandNumber == next.number
                            ? "play.circle.fill"
                            : "arrow.right.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(BookTheme.leather)
                        Text("下一条：\(commandTitle(next))")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.inkSecondary)
                            .lineLimit(2)
                    }
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
    }

    private func commandTitle(_ command: EvolutionPlanner.Command) -> String {
        let stripped = command.text
            .replacingOccurrences(of: #"^\d+[、.]\s*"#, with: "", options: .regularExpression)
        return stripped.isEmpty ? command.text : stripped
    }

    private func commandChip(_ command: EvolutionPlanner.Command) -> some View {
        let isNext = !command.isCompleted && command.number == pending.first?.number
        let isExecuting = isRunning && executingCommandNumber == command.number
        let title = commandTitle(command)

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: chipIcon(for: command, isNext: isNext, isExecuting: isExecuting))
                    .font(.system(size: 10, weight: .semibold))
                Text("#\(command.number)")
                    .font(BookTheme.captionFont)
            }
            Text(title)
                .font(.system(size: 10))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(chipForeground(for: command, isNext: isNext, isExecuting: isExecuting))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: 168, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(chipBackground(for: command, isNext: isNext, isExecuting: isExecuting))
                .overlay {
                    if isExecuting {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(BookTheme.leather.opacity(0.55), lineWidth: 1.5)
                    }
                }
        }
        .help(command.text)
    }

    private func chipIcon(for command: EvolutionPlanner.Command, isNext: Bool, isExecuting: Bool) -> String {
        if command.isCompleted { return "checkmark.circle.fill" }
        if isExecuting { return "play.circle.fill" }
        if isNext { return "arrow.right.circle.fill" }
        return "circle"
    }

    private func chipForeground(for command: EvolutionPlanner.Command, isNext: Bool, isExecuting: Bool) -> Color {
        if command.isCompleted { return BookTheme.jade }
        if isExecuting || isNext { return BookTheme.leather }
        return BookTheme.inkMuted
    }

    private func chipBackground(for command: EvolutionPlanner.Command, isNext: Bool, isExecuting: Bool) -> Color {
        if isExecuting { return BookTheme.gold.opacity(0.34) }
        if isNext { return BookTheme.gold.opacity(0.22) }
        return Color.white.opacity(command.isCompleted ? 0.55 : 0.35)
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
        if isLive { return "Agent 执行中…" }
        return "Agent 执行过程"
    }

    private var traceSummary: String {
        if isLive, let last = steps.last {
            let label = EvolutionToolLabels.localizedToolName(last.name)
            return last.status == .running ? "正在 \(label)" : "\(completedToolCount)/\(steps.count) 步"
        }
        if steps.contains(where: { $0.status == .failed }) {
            return "\(completedToolCount)/\(steps.count) 步 · 含失败"
        }
        return "\(steps.count) 个工具"
    }
}

/// AI 进化页：当前模型 token 用量 / 剩余 / 额度进度（随对话与 Agent 轮次实时更新）。
struct EvolutionTokenMeterPanel: View {
    let budget: ModelTokenBudget
    var isRunning: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("Token 额度", systemImage: "gauge.with.dots.needle.67percent")
                    .font(BookTheme.labelFont)
                    .foregroundStyle(BookTheme.leather)

                Spacer()

                if isRunning {
                    ProgressView().controlSize(.mini)
                }

                Text(budget.modelLabel)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("已用 \(budget.formattedUsed)")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(meterColor)
                Text("/ \(budget.formattedLimit)")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkSecondary)
                Text("· 剩余 \(budget.formattedRemaining)")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(budget.isOverLimit ? BookTheme.vermilion : BookTheme.inkMuted)
                Spacer()
                Text(budget.formattedPercentage)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(meterColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(BookTheme.pageEdge.opacity(0.55))
                    Capsule()
                        .fill(meterGradient)
                        .frame(width: geometry.size.width * budget.progressPercentage / 100.0)
                }
            }
            .frame(height: 8)

            HStack(spacing: 12) {
                tokenChip(title: "上下文", value: budget.contextTokens)
                tokenChip(title: "回复预留", value: budget.completionReserveTokens)
                tokenChip(title: "累计消耗", value: budget.sessionConsumedTokens)
            }

            if budget.isOverLimit {
                Label("已超出当前模型 token 额度，进化与追问已暂停", systemImage: "exclamationmark.triangle.fill")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.vermilion)
            } else if budget.isNearLimit {
                Label("接近 token 上限，建议清空对话或换更大上下文模型", systemImage: "exclamationmark.circle")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.42))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(meterColor.opacity(0.35), lineWidth: 1)
                }
        }
    }

    private var meterColor: Color {
        if budget.isOverLimit { return BookTheme.vermilion }
        if budget.isNearLimit { return .orange }
        return BookTheme.leather
    }

    private var meterGradient: LinearGradient {
        let colors: [Color]
        if budget.isOverLimit {
            colors = [BookTheme.vermilion.opacity(0.9), .orange.opacity(0.85)]
        } else if budget.isNearLimit {
            colors = [.orange.opacity(0.85), BookTheme.gold]
        } else {
            colors = [BookTheme.gold, BookTheme.goldSoft]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    private func tokenChip(title: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
            Text(TokenDisplay.format(value))
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkSecondary)
        }
    }
}

/// 进化页：自动升级开关与 Agent 后端状态摘要。
struct EvolutionControlStrip: View {
    @ObservedObject var settings = AppSettings.shared
    let isRunning: Bool
    let showsAgentTrace: Bool
    let explanationSource: ExplanationSource
    let providerLabel: String
    let modelLabel: String?
    let liveToolLabel: String?

    var body: some View {
        HStack(spacing: 10) {
            Toggle(isOn: $settings.autoEvolutionEnabled) {
                Text("自动升级")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkSecondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .disabled(isRunning)

            Spacer()

            if showsAgentTrace {
                if explanationSource == .cursor {
                    Label("Cursor Agent · 自动授权", systemImage: "checkmark.shield")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.jade)
                    Text(settings.selectedCursorModel.label)
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                } else {
                    Label("大模型 Agent · 本地工具", systemImage: "wrench.and.screwdriver")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.jade)
                    Text(llmAgentSubtitle)
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                        .lineLimit(1)
                }
            } else if settings.isLLMConfigured {
                Label("大模型模式", systemImage: "arrow.triangle.branch")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            }

            if let liveToolLabel, isRunning {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini)
                    Text(liveToolLabel)
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.leather)
                        .lineLimit(1)
                }
            }
        }
    }

    private var llmAgentSubtitle: String {
        let provider = providerLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let modelLabel, !modelLabel.isEmpty else { return provider }
        return "\(provider) · \(modelLabel)"
    }
}

/// 打包安装进度条（进化完成后 build-and-install）。
struct EvolutionRebuildBanner: View {
    let status: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text("正在自动升级")
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
        if isLive { return "执行步骤…" }
        return "执行步骤 (\(steps.count))"
    }

    private var summaryLabel: String {
        if failedCount > 0 {
            return "\(completedCount) 完成 · \(failedCount) 失败"
        }
        return "\(completedCount) 个工具"
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
                            Text("运行中")
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
                        detailBlock(title: "输入", text: detail, tint: BookTheme.leather)
                    }
                    if let result = step.resultSummary, !result.isEmpty {
                        detailBlock(title: "结果", text: result, tint: BookTheme.jade)
                    }
                    if let error = step.errorMessage, !error.isEmpty {
                        detailBlock(title: "错误", text: error, tint: BookTheme.vermilion)
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
                Button("复制输入") {
                    copyToPasteboard(input)
                }
                .buttonStyle(.plain)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)
            }
            if let result = step.resultSummary, !result.isEmpty {
                Button("复制结果") {
                    copyToPasteboard(result)
                }
                .buttonStyle(.plain)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.jade)
            }
            if step.hasFileRevealAction, let path = step.resolvedFilePath {
                Button("在 Finder 中显示") {
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
            Button("复制输入") {
                copyToPasteboard(input)
            }
        }
        if let result = step.resultSummary, !result.isEmpty {
            Button("复制结果") {
                copyToPasteboard(result)
            }
        }
        if step.hasFileRevealAction, let path = step.resolvedFilePath {
            Button("在 Finder 中显示") {
                revealInFinder(path: path)
            }
        }
        if step.hasExpandableDetail {
            Button(showsDetail ? "收起详情" : "展开详情") {
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
                    Text(isLive ? "思考中…" : "思考过程")
                        .font(BookTheme.captionFont)
                    if isLive {
                        ProgressView().controlSize(.mini)
                    }
                    Spacer()
                    Text("\(text.count) 字")
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

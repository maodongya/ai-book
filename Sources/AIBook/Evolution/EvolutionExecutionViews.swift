import AIBookEvolution
import AppKit
import SwiftUI

/// AI 进化页顶栏两块区域：进化（含模型）、队列。
enum EvolutionUtilityTab: String, CaseIterable, Identifiable {
    case evolution = "进化"
    case queue = "队列"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .evolution: return "arrow.triangle.2.circlepath"
        case .queue: return "list.number"
        }
    }
}

/// 顶栏 Tab 容器：合并进化操作与进化队列，节省主对话区纵向空间。
struct EvolutionUtilityTabsPanel: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var ollamaCatalog = OllamaModelCatalog.shared
    @AppStorage("evolutionUtilityTab") private var selectedTabRaw = EvolutionUtilityTab.evolution.rawValue

    let items: [OptimizationItem]
    let projectPath: String
    let isRunning: Bool
    let isAnalyzing: Bool
    let executingCommandNumber: Int?
    let budget: ModelTokenBudget
    let showsAgentTrace: Bool
    let liveToolLabel: String?
    let canRunEvolution: Bool
    let hasPending: Bool
    let isEvolutionRebuilding: Bool
    let onAnalyze: () -> Void
    let onEvolve: () -> Void
    let onStop: () -> Void
    let onAddUserItem: (String) -> Void
    let onSkip: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onPin: (UUID) -> Void
    let onRestore: (UUID) -> Void

    private var selectedTab: EvolutionUtilityTab {
        EvolutionUtilityTab(rawValue: selectedTabRaw) ?? .evolution
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabBar

            Divider()
                .overlay(BookTheme.pageEdge.opacity(0.65))

            Group {
                switch selectedTab {
                case .evolution:
                    evolutionTabContent
                case .queue:
                    EvolutionCommandQueuePanel(
                        items: items,
                        projectPath: projectPath,
                        isRunning: isRunning,
                        isAnalyzing: isAnalyzing,
                        executingCommandNumber: executingCommandNumber,
                        embeddedInTabs: true,
                        onAnalyze: onAnalyze,
                        onAddUserItem: onAddUserItem,
                        onSkip: onSkip,
                        onDelete: onDelete,
                        onPin: onPin,
                        onRestore: onRestore
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.18), value: selectedTabRaw)
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
        .task(id: settings.provider) {
            guard settings.provider == .ollama else { return }
            await ollamaCatalog.refresh(baseURL: settings.baseURL, apiKey: settings.apiKey)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(EvolutionUtilityTab.allCases) { tab in
                tabButton(tab)
            }
            Spacer(minLength: 0)
            tabStatusBadge
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func tabButton(_ tab: EvolutionUtilityTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTabRaw = tab.rawValue
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(tab.rawValue)
                    .font(BookTheme.captionFont)
            }
            .foregroundStyle(isSelected ? BookTheme.leatherShadow : BookTheme.inkMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    Capsule()
                        .fill(BookTheme.gold.opacity(0.38))
                        .overlay {
                            Capsule()
                                .strokeBorder(BookTheme.goldSoft.opacity(0.55), lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .help(tabHelp(tab))
    }

    @ViewBuilder
    private var tabStatusBadge: some View {
        if isRunning, let executingCommandNumber {
            Label("#\(executingCommandNumber)", systemImage: "play.circle.fill")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)
        } else if budget.isOverLimit {
            Label("超限", systemImage: "exclamationmark.triangle.fill")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.vermilion)
        } else if !items.isEmpty {
            let completed = items.filter { $0.status == .completed }.count
            Text("\(completed)/\(items.count)")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
        }
    }

    private func tabHelp(_ tab: EvolutionUtilityTab) -> String {
        switch tab {
        case .evolution: return "进化操作、后端与模型、自动升级"
        case .queue: return "优化队列与源码路径"
        }
    }

    private var evolutionTabContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            evolutionActionRow
            EvolutionModelSettingsSection()
            EvolutionControlStrip(
                isRunning: isRunning,
                showsAgentTrace: showsAgentTrace,
                explanationSource: settings.explanationSource,
                providerLabel: settings.provider.rawValue,
                modelLabel: settings.explanationSource == .llm ? settings.model : nil,
                liveToolLabel: liveToolLabel,
                embeddedInTabs: true
            )
        }
        .padding(12)
    }

    private var evolutionActionRow: some View {
        HStack(spacing: 8) {
            BookPageActionButton(
                title: "分析优化",
                icon: "magnifyingglass",
                isProminent: false,
                isDisabled: isRunning || isEvolutionRebuilding || !canRunEvolution
            ) {
                onAnalyze()
            }

            BookPageActionButton(
                title: "进化",
                icon: "arrow.triangle.2.circlepath",
                isProminent: !isRunning && !isEvolutionRebuilding && canRunEvolution && hasPending,
                isDisabled: isRunning || isEvolutionRebuilding || !canRunEvolution || !hasPending
            ) {
                onEvolve()
            }

            if isRunning {
                BookPageActionButton(
                    title: "停止",
                    icon: "stop.fill",
                    isProminent: true
                ) {
                    onStop()
                }
            }

            Spacer()

            if isAnalyzing, isRunning {
                Label("分析中", systemImage: "magnifyingglass")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)
            } else if let number = executingCommandNumber, isRunning {
                Label("第 \(number) 条", systemImage: "number")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)
            }
        }
    }
}

/// 进化 Tab：后端切换与模型选择（原分散在顶栏与输入区）。
struct EvolutionModelSettingsSection: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var ollamaCatalog = OllamaModelCatalog.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("进化后端")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Picker("进化后端", selection: $settings.explanationSource) {
                    ForEach(ExplanationSource.allCases) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if settings.explanationSource == .cursor {
                cursorModelRow
            } else {
                llmModelRow
            }
        }
    }

    private var cursorModelRow: some View {
        HStack(spacing: 8) {
            Label("Cursor 模型", systemImage: "cursorarrow.rays")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
            Picker("模型", selection: $settings.selectedCursorModel) {
                ForEach(CursorModelOption.allCases) { model in
                    Text(model.label).tag(model)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 200)
            Spacer()
            if settings.isCursorRunnable {
                Label("已就绪", systemImage: "checkmark.circle.fill")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.jade)
            } else {
                Label("需配置 Key 或桥接", systemImage: "exclamationmark.circle")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var llmModelRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("提供商")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                Picker("提供商", selection: $settings.provider) {
                    if !settings.configuredLLMProviders.isEmpty {
                        Section("已配置") {
                            ForEach(settings.configuredLLMProviders) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }
                    } else {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 150)
                .onChange(of: settings.provider) { _ in
                    settings.applyProviderDefaults()
                }
            }

            HStack(spacing: 8) {
                Text("模型")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                llmModelPicker
                Spacer()
                if settings.isLLMConfigured {
                    Label("已连接", systemImage: "checkmark.circle.fill")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.jade)
                } else {
                    Label("未配置 Key", systemImage: "exclamationmark.circle")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private var llmModelPicker: some View {
        if settings.provider == .qwen {
            Picker("模型", selection: $settings.model) {
                ForEach(QwenBailianConfig.suggestedModels, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 180)
        } else if settings.provider == .ollama {
            HStack(spacing: 6) {
                if ollamaCatalog.models.isEmpty && !ollamaCatalog.isLoading {
                    TextField("model", text: $settings.model)
                        .textFieldStyle(.plain)
                        .font(BookTheme.captionFont)
                        .frame(maxWidth: 140)
                } else {
                    Picker("模型", selection: $settings.model) {
                        ForEach(ollamaCatalog.modelNamesIncluding(settings.model), id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 160)
                }
                Button {
                    Task {
                        await ollamaCatalog.refresh(
                            baseURL: settings.baseURL,
                            apiKey: settings.apiKey,
                            force: true
                        )
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(BookTheme.leather)
            }
        } else {
            TextField("model", text: $settings.model)
                .textFieldStyle(.plain)
                .font(BookTheme.captionFont)
                .frame(maxWidth: 160)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(BookTheme.pageEdge, lineWidth: 1)
                        }
                }
        }
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
    var onAnalyze: (() -> Void)?
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
                    Text("\(completedCount)/\(items.count) 已完成")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                    Spacer()
                    if isAnalyzing, isRunning {
                        Label("分析中", systemImage: "magnifyingglass")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.leather)
                    } else if isRunning, let executingCommandNumber {
                        Label("执行 #\(executingCommandNumber)", systemImage: "play.circle.fill")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.leather)
                    }
                }
            }

            if items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("点「分析优化」，让 AI 找出可改进处")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                    if let onAnalyze {
                        BookPageActionButton(
                            title: "分析优化",
                            icon: "magnifyingglass",
                            isProminent: true,
                            isDisabled: isRunning
                        ) {
                            onAnalyze()
                        }
                    }
                }
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
                        Text("下一条：\(next.title)")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.inkSecondary)
                            .lineLimit(2)
                    }
                }
            }

            if onAddUserItem != nil {
                HStack(spacing: 6) {
                    TextField("手写一条优化…", text: $draftTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(BookTheme.captionFont)
                    Button("添加") {
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
                    Text(item.source == .ai ? "AI" : "手写")
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
                        Text("高优")
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
                    Button("置顶") { onPin(item.id) }
                }
                if let onSkip {
                    Button("跳过") { onSkip(item.id) }
                }
                if let onDelete {
                    Button("删除", role: .destructive) { onDelete(item.id) }
                }
            } else if item.status == .skipped {
                if let onRestore {
                    Button("恢复") { onRestore(item.id) }
                }
                if let onDelete {
                    Button("删除", role: .destructive) { onDelete(item.id) }
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
        case .pending: return "待办"
        case .running: return "执行中"
        case .completed: return "已完成"
        case .skipped: return "已跳过"
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

/// 进化页：自动升级开关与 Agent 后端状态摘要。
struct EvolutionControlStrip: View {
    @ObservedObject var settings = AppSettings.shared
    let isRunning: Bool
    let showsAgentTrace: Bool
    let explanationSource: ExplanationSource
    let providerLabel: String
    let modelLabel: String?
    let liveToolLabel: String?
    var embeddedInTabs: Bool = false

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

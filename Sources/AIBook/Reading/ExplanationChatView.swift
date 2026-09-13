import AppKit
import SwiftUI

/// 右页：读书助手与 AI 进化（讲解 / 翻译 / 对话区壳层）。
struct ExplanationChatView: View {
    @EnvironmentObject private var viewModel: ReadingViewModel  // 右页 tab、翻译、进化都从这读
    @ObservedObject private var settings = AppSettings.shared  // LLM/Cursor 配好没有，语言变了刷新
    @ObservedObject private var styleManager = BookStyleManager.shared  // 换字体整页重建
    var learningPaneFocus: LearningPaneFocus = .both  // 书桌还是右页全屏
    var onLearningPaneFocusChange: ((LearningPaneFocus) -> Void)?  // 全屏按钮回写宿主；sheet 里为 nil
    @AppStorage("aiBook.readingComposerVisible") private var isReadingComposerVisible = true  // 输入框展开，跨启动记住
    @AppStorage("aiBook.readingChromeVisible") private var isReadingChromeVisible = true  // 顶栏/分栏显隐，跨启动记住

    /// 右页：读书助手或进化，外加配置条。
    var body: some View {
        let _ = settings.localizationRevision  // 语言变了强迫 body 重算 L10n
        VStack(spacing: 0) {  // 页内贴齐，分隔靠各段自己的 padding
            switch viewModel.rightPageTab {  // 助手和进化是两套页
            case .readingAssistant:  // 讲解/翻译
                readingAssistantPage  // 分栏 + 内容 + 输入
            case .aiEvolution:  // 进化对话
                aiEvolutionPage  // 队列 + 对话 + 输入
            }
        }
        .padding(.bottom, 2)  // 和书桌底留一线
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // 吃掉右页剩余
        .onAppear {  // 每次露出来核对钥匙，避免过期
            settings.reloadCursorAPIKey()  // 钥匙可能在钥匙串里被换过
        }
    }

    /// 读书助手页：分栏加输入。
    private var readingAssistantPage: some View {
        VStack(spacing: 0) {  // 页内贴齐，分隔靠各段自己的 padding
            if isReadingChromeVisible {  // 沉浸时藏讲解工具
                configurationNotice  // 没配后端先提示
                readingAssistantPanelSwitcher  // 讲解/翻译 + 全屏
            }

            readingAssistantContent  // 当前分栏
                .frame(maxWidth: .infinity, maxHeight: .infinity)  // 吃掉右页剩余
                .overlay(alignment: .topTrailing) {  // 藏铬时给一个恢复钮
                    if !isReadingChromeVisible {  // 沉浸时只留恢复
                        readingChromeRestoreControl  // 回到书桌铬
                            .padding(10)  // 离开角一点，避免贴边难点
                    }
                }

            readingComposerSection  // 底栏输入或折叠条
        }
    }

    @ViewBuilder
    /// 当前分栏内容（讲解或翻译）。
    private var readingAssistantContent: some View {
        switch viewModel.assistant.readingAssistantPanel {  // 和顶栏 Picker 同一份状态
        case .explanation:  // 讲解对话
            explanationPanel  // 记录 + 讲解工具条
        case .translation:  // 翻译
            translationPanel  // 对照表或长文 + 翻译工具条
        }
    }

    @ViewBuilder
    /// 底部输入；折叠时换成短条。
    private var readingComposerSection: some View {
        if !isReadingChromeVisible {  // 沉浸时只留恢复
            EmptyView()  // 沉浸时连折叠条也藏
        } else if isReadingComposerVisible {  // 展开才上完整输入
            composer(for: .readingAssistant)  // 书内 LLM 输入
        } else {
            collapsedReadingComposerBar  // 只留状态和展开
        }
    }

    /// 折叠输入条：状态和展开。
    private var collapsedReadingComposerBar: some View {
        HStack(spacing: 8) {  // 转圈和状态
            if viewModel.isRunning {  // 跑着时折叠条给出停
                HStack(spacing: 8) {  // 转圈和状态
                    ProgressView().controlSize(.small)  // 小转圈
                    Text(collapsedRunningStatusText)  // 讲解或翻译进行中
                        .font(BookTheme.captionFont)  // 说明字号
                        .foregroundStyle(BookTheme.leather)  // 进行中用皮色
                        .lineLimit(1)  // 长文截断
                }

                BookPageActionButton(  // 和左页同一套停按钮
                    title: BookL10n.string("action.stop"),  // 停当前跑
                    icon: "stop.fill",  // 停
                    isDisabled: false  // 折叠条出现时一定能停
                ) {
                    viewModel.stopCurrentRun()  // 讲解/翻译/进化共用停
                }
            }

            Spacer(minLength: 8)  // 朗读钮靠右

            Button {  // 点按
                withAnimation(.easeOut(duration: 0.18)) {  // 展开输入短动画
                    isReadingComposerVisible = true  // 写回 AppStorage
                }
            } label: {
                Image(systemName: "chevron.up")  // 展开输入
                    .font(.system(size: 12, weight: .semibold))  // 小图标字重
                    .foregroundStyle(BookTheme.leather)  // 进行中用皮色
            }
            .buttonStyle(.plain)  // 不要系统默认凸起
            .help(BookL10n.string("help.showInput"))  // 展开输入说明
        }
        .padding(.horizontal, 14)  // 左右边距
        .padding(.vertical, 8)  // 上下边距
        .background {  // 底或选中态
            RoundedRectangle(cornerRadius: 14, style: .continuous)  // 折叠条底
                .fill(Color.white.opacity(0.35))  // 半透明，露出书页
                .overlay {  // 叠一层边或控件
                    RoundedRectangle(cornerRadius: 14, style: .continuous)  // 折叠条底
                        .strokeBorder(BookTheme.pageEdge.opacity(0.55), lineWidth: 1)  // 书边描边
                }
        }
        .padding(.horizontal, 12)  // 和表头左右对齐
        .padding(.bottom, 6)  // 和窗口底留气
    }

    /// 折叠条上的运行状态短文案。
    private var collapsedRunningStatusText: String {
        let text = viewModel.runningStatusText(for: .readingAssistant)  // 当前任务一句话
        return text.isEmpty ? BookL10n.string("llm.generating") : text  // 还没状态字就用生成中
    }

    /// 讲解 / 翻译分栏切换。
    private var readingAssistantPanelSwitcher: some View {
        HStack(spacing: 8) {  // 转圈和状态
            Picker(BookL10n.string("picker.rightPanel"), selection: Binding(  // 讲解/翻译
                get: { viewModel.readingAssistantPanel },  // 和会话同一份
                set: { viewModel.readingAssistantPanel = $0 }  // 写回，对照表/讲解跟着切
            )) {
                ForEach(ReadingAssistantPanel.allCases) { panel in  // 两栏
                    Text(panel.toolbarTitle).tag(panel)  // 短标题
                }
            }
            .pickerStyle(.segmented)  // 分段，不是菜单
            .labelsHidden()  // 标题只给无障碍

            if let onLearningPaneFocusChange {  // 书桌才有全屏；sheet 没有
                readingAssistantRightFullscreenButton(onChange: onLearningPaneFocusChange)  // 右页全屏
            }
        }
        .padding(.horizontal, 14)  // 左右边距
        .padding(.top, 6)  // 顶边距
        .padding(.bottom, 4)  // 底边距
    }

    /// 从全屏学习区回到书桌。
    private var readingChromeRestoreControl: some View {
        Button(action: exitReadingFocusMode) {  // 退出沉浸铬
            Image(systemName: "chevron.down")  // 恢复顶栏
                .font(.system(size: 12, weight: .semibold))  // 小图标字重
                .foregroundStyle(styleManager.tokens.colors.ink)  // 跟当前主题墨
                .padding(.horizontal, 10)  // 左右边距
                .padding(.vertical, 6)  // 上下边距
                .background { lessonPlanToolbarCapsule }  // 和教案工具同一粒
        }
        .buttonStyle(.plain)  // 不要系统默认凸起
        .help(BookL10n.string("help.showToolbar"))  // 恢复工具条说明
    }

    /// 右页全屏。再点退出。
    private func readingAssistantRightFullscreenButton(
        onChange: @escaping (LearningPaneFocus) -> Void  // 全屏状态写回书桌
    ) -> some View {
        let isFocused = learningPaneFocus == .trailing  // 已经是右页全屏

        return Button {  // 再点切回双页
            onChange(isFocused ? .both : .trailing)  // 再点回到左右都在
        } label: {
            Image(systemName: isFocused ? "rectangle.split.2x1" : "arrow.up.left.and.arrow.down.right")  // 全屏/恢复双页
                .font(.system(size: 11, weight: .semibold))  // 全屏钮更小，不抢分段
                .foregroundStyle(BookTheme.leather.opacity(0.72))  // 皮色强调
                .frame(width: 24, height: 24)  // 锁宽
                .background {  // 底或选中态
                    Circle()  // 恢复钮徽标底
                        .fill(BookTheme.pageEdge.opacity(0.35))  // 浅底
                }
        }
        .buttonStyle(.plain)  // 不要系统默认凸起
        .help(  // 悬停说明
            isFocused
                ? BookL10n.string("help.restoreSpreadFromFocus")  // 已全屏：恢复双页
                : BookL10n.string("help.rightFullscreen")  // 未全屏：右页铺满
        )
    }

    /// 恢复双栏。
    private func exitReadingFocusMode() {
        withAnimation(.easeOut(duration: 0.18)) {  // 展开输入短动画
            isReadingChromeVisible = true  // 退出沉浸时把顶栏也拉回来
            isReadingComposerVisible = true  // 写回 AppStorage
        }
    }

    /// 讲解对话区。
    private var explanationPanel: some View {
        ZStack(alignment: .topLeading) {  // 叠层
            ExplanationChatTranscriptView()  // 讲解气泡，输入在外
                .frame(maxWidth: .infinity, maxHeight: .infinity)  // 吃掉右页剩余

            SelectableTextView(  // 译文长文，和左页同一套编辑器
                text: Binding(  // 和会话正文双向绑
                    get: { viewModel.explanationSelectionText },  // 讲解面板划词
                    set: { viewModel.explanationSelectionText = $0 }  // 写回，供插入引用
                ),
                onSelectionChange: { selection, _ in
                    viewModel.assistant.updateExplanationPanelSelection(selection)  // 划词范围记下
                },
                appearance: .editor,  // 讲解用编辑器外观
                isEditable: false,
                selectAllSignal: viewModel.assistant.explanationSelectAllSignal  // 工具条全选打到这篇
            )
            .frame(width: 0, height: 0)  // 锁宽
            .accessibilityHidden(true)  // 装饰铬不对 VoiceOver 重复读

            if isReadingChromeVisible {  // 沉浸时藏讲解工具
                VStack {
                    HStack(spacing: 8) {  // 转圈和状态
                        Spacer()  // 把后续控件推开
                        explanationToolbar  // 新建/存/读/清
                    }
                    Spacer()  // 把后续控件推开
                }
                .padding(10)  // 离开角一点，避免贴边难点
            }
        }
    }

    /// 讲解工具条。
    private var explanationToolbar: some View {
        HStack(spacing: 8) {  // 转圈和状态
            explanationToolbarButton(title: BookL10n.string("action.new")) {  // 新开讲解
                viewModel.assistant.newExplanationDocument()  // 新开一份讲解，旧的先确认
            }
            .disabled(viewModel.isRunning)  // 不可用时灰掉，避免误操作

            explanationToolbarButton(title: BookL10n.string("action.save")) {  // 另存讲解
                viewModel.assistant.saveExplanationDocument()  // 另存讲解
            }
            .disabled(!viewModel.assistant.hasExplanationContent)  // 不可用时灰掉，避免误操作

            explanationToolbarButton(title: BookL10n.string("action.open")) {  // 打开已存讲解
                viewModel.assistant.openExplanationDocument()  // 打开已存讲解
            }
            .disabled(viewModel.isRunning)  // 不可用时灰掉，避免误操作

            explanationToolbarButton(title: BookL10n.string("action.selectAll")) {  // 全选讲解
                viewModel.assistant.selectAllExplanation()  // 全选讲解正文
            }
            .disabled(!viewModel.assistant.hasExplanationContent || viewModel.isRunning)  // 不可用时灰掉，避免误操作

            explanationToolbarButton(title: BookL10n.string("action.clear")) {  // 清空讲解
                viewModel.assistant.clearExplanation()  // 清空讲解，留欢迎
            }
            .disabled(viewModel.isRunning || !viewModel.assistant.hasExplanationContent)  // 不可用时灰掉，避免误操作

            if viewModel.assistant.isSpeakingExplanation && !viewModel.isRunning {  // 朗读中才给暂停，跑任务时不给
                explanationToolbarButton(  // 朗读/暂停
                    title: viewModel.assistant.isExplanationSpeechPaused ? BookL10n.string("action.resume") : BookL10n.string("action.pause")  // 朗读中才出现暂停
                ) {
                    viewModel.assistant.toggleExplanationSpeechPause()  // 暂停/继续这条讲解
                }
            }

            explanationToolbarButton(  // 朗读/暂停
                title: viewModel.assistant.isSpeakingExplanation ? BookL10n.string("action.stop") : BookL10n.string("action.readAloud")  // 在读显示停
            ) {
                viewModel.assistant.readExplanationAloud()  // 没有在读就读全文，在读就停
            }
            .disabled(viewModel.isRunning || (!viewModel.assistant.hasExplanationContent && !viewModel.assistant.isSpeakingExplanation))  // 不可用时灰掉，避免误操作
        }
        .id(styleManager.revision)  // 字体变整页重建，避免残列宽
    }

    /// 讲解栏工具按钮。
    private func explanationToolbarButton(
        title: String,
        action: @escaping () -> Void  // 点按
    ) -> some View {
        Button(action: action) {  // 工具条小按钮
            Text(title)  // 按钮文案
                .font(styleManager.tokens.typography.captionFont)  // 跟当前主题说明字
                .foregroundStyle(styleManager.tokens.colors.ink)  // 跟当前主题墨
                .padding(.horizontal, 10)  // 左右边距
                .padding(.vertical, 6)  // 上下边距
                .background { lessonPlanToolbarCapsule }  // 和教案工具同一粒
        }
        .buttonStyle(.plain)  // 不要系统默认凸起
    }

    /// 翻译编辑或对照表。
    private var translationPanel: some View {
        VStack(spacing: 0) {  // 页内贴齐，分隔靠各段自己的 padding
            if isReadingChromeVisible {  // 沉浸时藏讲解工具
                translationToolbar
            }
            if viewModel.translation.showsTranslationTableView,  // 对照表开着才可能出非严格提示
               let alignment = viewModel.translation.translationAlignment,  // 没对齐就没有提示
               alignment.mode == .paragraph,  // 只有段对齐才走严格门
               !alignment.strictParagraphValidated,  // 启发式对齐要提示不是验收过的
               !alignment.isStale {  // 过期对齐另有黄标，这里不叠
                Text(BookL10n.string("translation.table.nonStrictHint"))  // 提醒这表还没过严格门
                    .font(BookTheme.captionFont)  // 说明字号
                    .foregroundStyle(BookTheme.inkSecondary)  // 次要墨
                    .frame(maxWidth: .infinity, alignment: .leading)  // 撑满宽
                    .padding(.horizontal, 12)  // 和表头左右对齐
                    .padding(.vertical, 6)  // 上下边距
            }
            if viewModel.translation.showsTranslationTableView, let alignment = viewModel.translation.translationAlignment {  // 有对齐才画表头/表
                TranslationTableColumnHeader(  // 和表体同一套列宽
                    alignment: alignment,
                    isEditable: !viewModel.isRunning  // 跑着锁表，避免和生成打架
                )
                .padding(.horizontal, 12)  // 和表头左右对齐
            }
            ZStack(alignment: .topTrailing) {  // 生成中角标叠在表上
                Group {  // 只为了套修饰
                    if viewModel.translation.showsTranslationTableView, let alignment = viewModel.translation.translationAlignment {  // 有对齐才画表头/表
                        TranslationTableView(  // 对照表
                            alignment: alignment,
                            isEditable: !viewModel.isRunning,  // 跑着锁长文
                            isSourceColumnEditable: !viewModel.translation.usesStrictParagraphTable,  // 过严格门的表锁原文
                            allowsSplitTranslation: !viewModel.translation.usesStrictParagraphTable,  // 过严格门禁止拆行
                            highlightedBlockID: viewModel.translation.translationTableHighlightedBlockID,  // 左页可见段
                            scrollTargetBlockID: viewModel.translation.translationTableScrollTargetID,  // 左页跳段
                            focusTranslationBlockID: viewModel.translation.translationTableFocusTranslationBlockID,  // 刚生成完聚焦译文
                            onSelectBlock: { block in
                                viewModel.translation.handleTranslationTableVisibleBlock(block)  // 点行同步左页
                            },
                            onUpdateBlock: { id, source, translation, note in
                                viewModel.translation.updateTranslationTableBlock(  // 单元格提交
                                    id: id,
                                    sourceText: source,
                                    translationText: translation,
                                    note: note
                                )
                            },
                            onSplitTranslation: { id, before, after in
                                viewModel.splitTranslationTableBlock(  // 回车拆行
                                    id: id,
                                    translationBefore: before,
                                    translationAfter: after
                                )
                            },
                            onClearFocusTranslation: {
                                viewModel.translation.translationTableFocusTranslationBlockID = nil  // 聚焦用过即清
                            }
                        )
                    } else if viewModel.translation.showsTranslationProgressSheet {
                        translationProgressInSheetPlaceholder
                    } else {
                        lessonPlanEditor
                    }
                }
            }
        }
    }

    /// 翻译在弹出层进行，右页不展示流式 JSON/教案过程。
    private var translationProgressInSheetPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(BookL10n.string("translation.progress.inSheet"))
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.leather)
            }
            Text(BookL10n.string("translation.progress.hint"))
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// 翻译工具条。
    private var translationToolbar: some View {
        HStack(spacing: 10) {  // 横排
            if viewModel.translation.translationAlignment?.isStale == true {  // 原文改过，对齐要重来
                Image(systemName: "exclamationmark.triangle.fill")  // 过期黄标
                    .font(BookTheme.captionFont)  // 说明字号
                    .foregroundStyle(.orange)  // 警告，不是错误朱红
                    .help(BookL10n.string("help.alignStale"))  // 过期原因
            }

            Toggle(BookL10n.string("translation.tableCompare"), isOn: Binding(  // 对照表/长文
                get: { viewModel.translationTableViewEnabled },  // 偏好里的开关
                set: { viewModel.translationTableViewEnabled = $0 }  // 写回，立刻切视图
            ))
                .toggleStyle(.switch)  // 开关，不是勾选
                .controlSize(.small)  // 塞进行高
                .font(BookTheme.captionFont)  // 说明字号
                .disabled(!viewModel.translation.canUseTranslationTableView)  // 没对齐块就别开表

            translationToolbarButton(title: BookL10n.string("translation.alignSource")) {  // 本地对齐
                viewModel.translation.alignTranslationWithSource()  // 本地对齐，失败可弹
            }
            .disabled(!viewModel.translation.canAlignTranslationWithSource)  // 没译文或已锁定不能对齐

            if viewModel.translation.isTranslationAlignmentLocked {  // 已锁给出解锁
                translationToolbarButton(title: BookL10n.string("translation.unlock")) {  // 解锁整体对齐
                    viewModel.unlockTranslationAlignment()  // 解开后才能整体对齐和偏移
                }
            } else if viewModel.translation.canUseTranslationTableView {  // 有表才能锁
                translationToolbarButton(title: BookL10n.string("translation.lock"), prominent: true) {  // 锁定，皮色强调
                    viewModel.lockTranslationAlignment()  // 锁整体对齐，单行仍可改
                }
            }

            Spacer(minLength: 8)  // 朗读钮靠右

            if !viewModel.translation.showsTranslationTableView {  // 长文模式才有全选
                translationToolbarButton(title: BookL10n.string("action.selectAll")) {  // 长文全选
                    viewModel.translation.selectAllRightPage()  // 全选译文长文
                }
                .disabled(  // 不可用时灰掉，避免误操作
                    viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 空译文不能全选
                        || viewModel.isRunning  // 跑着不让全选
                )

                if viewModel.assistant.isSpeakingExplanation && !viewModel.isRunning {  // 朗读中才给暂停，跑任务时不给
                    translationToolbarButton(  // 朗读译文
                        title: viewModel.assistant.isExplanationSpeechPaused ? BookL10n.string("action.resume") : BookL10n.string("action.pause")  // 朗读中才出现暂停
                    ) {
                        viewModel.assistant.toggleExplanationSpeechPause()  // 暂停/继续这条讲解
                    }
                }

                translationToolbarButton(  // 朗读译文
                    title: viewModel.assistant.isSpeakingExplanation ? BookL10n.string("action.stop") : BookL10n.string("action.readAloud")  // 在读显示停
                ) {
                    if viewModel.assistant.isSpeakingExplanation {  // 已经在读就停，否则读教案/译文
                        viewModel.assistant.stopExplanationSpeech()  // 停朗读
                    } else {
                        viewModel.assistant.readLessonPlanAloud()  // 读右页译文/教案
                    }
                }
                .disabled(  // 不可用时灰掉，避免误操作
                    viewModel.isRunning  // 跑着禁用
                        || (  // 空译文且没在读才禁用朗读
                            viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 空译文不能全选
                                && !viewModel.assistant.isSpeakingExplanation  // 正在读仍允许点停
                        )
                )
            }
        }
        .font(BookTheme.captionFont)  // 说明字号
        .padding(.horizontal, 12)  // 和表头左右对齐
        .padding(.vertical, 6)  // 上下边距
    }

    /// 翻译栏工具按钮。
    private func translationToolbarButton(
        title: String,
        prominent: Bool = false,  // 锁定钮用皮色
        action: @escaping () -> Void  // 点按
    ) -> some View {
        Button(action: action) {  // 工具条小按钮
            Text(title)  // 按钮文案
                .foregroundStyle(prominent ? BookTheme.leather : BookTheme.ink)  // 锁定用皮色强调
        }
        .buttonStyle(.plain)  // 不要系统默认凸起
    }

    /// 进化对话页。
    private var aiEvolutionPage: some View {
        VStack(spacing: 0) {  // 页内贴齐，分隔靠各段自己的 padding
            configurationNotice  // 没配后端先提示

            EvolutionUtilityTabsPanel(  // 优化队列
                items: viewModel.evolution.evolutionItems,  // 按编号排
                projectPath: SelfEvolution.sourceProjectPath(),  // 本仓库路径，给打开命令用
                isRunning: viewModel.isRunning,  // 跑着时队列操作要收
                isAnalyzing: viewModel.isAnalyzing,  // 分析轮和执行轮按钮不同
                executingCommandNumber: viewModel.evolution.executingEvolutionCommandNumber,  // 正在做的那条
                budget: viewModel.evolutionTokenBudget,  // 超限要提示
                liveToolLabel: viewModel.evolutionLiveToolLabel,  // 当前工具名
                lastRequestId: viewModel.evolution.evolutionLastRequestId,  // 排错用
                hasPending: viewModel.evolution.hasPendingOptimization,  // 还有未做的
                onAddUserItem: { viewModel.evolution.addUserOptimization(title: $0) },  // 用户自加一项
                onSkip: { viewModel.evolution.skipOptimization(id: $0) },  // 跳过
                onDelete: { viewModel.evolution.deleteOptimization(id: $0) },  // 删项
                onPin: { viewModel.evolution.pinOptimization(id: $0) },  // 置顶
                onRestore: { viewModel.evolution.restoreOptimization(id: $0) }  // 恢复跳过的
            )

            if viewModel.evolution.isEvolutionRebuilding {  // 重建工程时出横幅
                EvolutionRebuildBanner(status: viewModel.evolution.evolutionRebuildStatus)  // 重建进度
                    .padding(.horizontal, 14)  // 左右边距
                    .padding(.bottom, 4)  // 底边距
            }

            ExplanationChatTranscriptView()  // 讲解气泡，输入在外
                .frame(maxWidth: .infinity, maxHeight: .infinity)  // 吃掉右页剩余

            composer(for: .aiEvolution)  // Cursor 输入
        }
    }

    @ViewBuilder
    /// 未配后端时的说明。
    private var configurationNotice: some View {
        if viewModel.rightPageTab == .aiEvolution {  // 进化看 Cursor，助手看书内 LLM
            if !settings.isCursorRunnable {  // 没钥匙/模型就先配
                CursorConfigPanel()  // 就地配 Cursor
                    .padding(.horizontal, 16)  // 左右边距
                    .padding(.vertical, 6)  // 上下边距
            }
        } else if !settings.isBookLLMConfigured {  // 助手页没配书内 LLM
            bookConfigBanner  // 引导去书籍设置
                .padding(.horizontal, 16)  // 左右边距
                .padding(.vertical, 6)  // 上下边距
        }
    }

    /// 书内 LLM 未配好的横幅。
    private var bookConfigBanner: some View {
        HStack(spacing: 8) {  // 转圈和状态
            Image(systemName: "book.closed.fill")  // 书内 LLM
                .foregroundStyle(BookTheme.gold)  // 金色强调
            Text(BookL10n.string("banner.bookLLM"))  // 还没配模型
                .font(BookTheme.captionFont)  // 说明字号
                .foregroundStyle(BookTheme.inkSecondary)  // 次要墨
            Spacer(minLength: 8)  // 朗读钮靠右
            Button(BookL10n.string("settings.book")) {  // 打开书籍设置
                viewModel.openBookSettings()  // 弹设置
            }
            .font(BookTheme.captionFont)  // 说明字号
            .foregroundStyle(BookTheme.leather)  // 进行中用皮色
        }
        .padding(12)  // 内边
        .frame(maxWidth: .infinity, alignment: .leading)  // 撑满宽
        .background {  // 底或选中态
            RoundedRectangle(cornerRadius: 10, style: .continuous)  // 圆角底或边
                .fill(BookTheme.selection.opacity(0.3))  // 横幅浅金底
        }
    }

    @ViewBuilder
    /// 按右页 Tab 选输入条。
    private func composer(for mode: RightPageTab) -> some View {
        if mode == .aiEvolution {  // 进化走 Cursor 输入
            CursorComposerView(mode: mode)  // Cursor 对话输入
        } else {
            LLMComposerView(  // 书内 LLM 输入
                mode: mode,
                onCollapse: {
                    withAnimation(.easeOut(duration: 0.18)) {  // 展开输入短动画
                        isReadingComposerVisible = false  // 折叠输入，多给对话高度
                    }
                }
            )
        }
    }

    /// 教案编辑器。
    private var lessonPlanEditor: some View {
        ZStack(alignment: .topLeading) {  // 叠层
            if viewModel.lessonPlanContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {  // 空译文出占位，不挡编辑器
                lessonPlanPlaceholder
            }

            SelectableTextView(  // 译文长文，和左页同一套编辑器
                text: Binding(  // 和会话正文双向绑
                    get: { viewModel.lessonPlanContent },  // 教案/译文正文
                    set: { viewModel.lessonPlanContent = $0 }  // 写回会话
                ),
                onSelectionChange: { selection, _ in
                    viewModel.assistant.updateLessonPlanSelection(selection)  // 划词给讲解引用
                },
                onVisibleRangeChange: { range, _ in
                    viewModel.translation.handleTranslationTextScroll(visibleRange: range)  // 长文滚动手势同步左页
                },
                scrollProxy: viewModel.translation.translationTextScrollProxy,  // 左页跳段时滚长文
                isEditable: !viewModel.isRunning,  // 跑着锁长文
                selectAllSignal: viewModel.document.rightSelectAllSignal  // 工具条全选打到这个视图
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)  // 吃掉右页剩余
        }
    }

    /// 教案工具胶囊。
    private var lessonPlanToolbarCapsule: some View {
        let colors = styleManager.tokens.colors  // 胶囊跟当前主题
        return Capsule()  // 工具条小按钮底
            .fill(colors.menuItemFill)  // 菜单同色，避免另起一套
            .overlay {  // 叠一层边或控件
                Capsule()  // 胶囊底
                    .strokeBorder(colors.menuItemBorder, lineWidth: 1)  // 细边
            }
    }

    /// 教案空状态。
    private var lessonPlanPlaceholder: some View {
        Text(BookL10n.string("translation.emptyHint"))  // 还没译文时的说明
            .font(BookTheme.captionFont)  // 说明字号
            .foregroundStyle(BookTheme.inkMuted)  // 弱墨
            .padding(.horizontal, 36)  // 和对话区左右对齐
            .padding(.vertical, 32)  // 和对话区顶底对齐
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)  // 吃掉剩余空间
            .allowsHitTesting(false)  // 角标不挡下面的编辑
    }

}

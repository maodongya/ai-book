import SwiftUI

/// 左页目录树。点文件才打开，点文件夹只展开。
struct DirectoryBrowserView: View {
    let sessions: [DirectoryBrowserRootSession]  // 已打开的根，侧栏数据源
    let selectedSessionID: UUID?  // 当前高亮根；nil 时用第一个
    let onSelectSession: (UUID) -> Void  // 点侧栏行，宿主记下 id
    let onAddDirectory: () -> Void  // 加号：系统选目录再插入
    let onRemoveSession: (UUID) -> Void  // 去掉这个根，不删磁盘
    let onToggleExpanded: (UUID, String) -> Void  // 展开/收起树节点，键是路径
    let onOpen: (URL, DirectoryFileOpenTarget) -> Void  // 打开到原文/译文/讲解
    let onDismiss: () -> Void  // 关 sheet，不改选中文件

    @ObservedObject private var styleManager = BookStyleManager.shared  // 换字体整页重建
    @State private var selectedFileURL: URL?  // 树里高亮的文件；切根时 sync 会改
    @State private var openTarget: DirectoryFileOpenTarget = .original  // 打开到哪一栏，默认原文

    /// 当前侧栏高亮的根；没选就用第一个。
    private var selectedSession: DirectoryBrowserRootSession? {
        guard let selectedSessionID else { return sessions.first }  // 没选就落第一个根
        return sessions.first { $0.id == selectedSessionID } ?? sessions.first  // id 对不上也回退，避免空树
    }

    /// 底部打开只对文件亮，文件夹不算。
    private var selectedIsFile: Bool {
        guard let selectedFileURL else { return false }  // 没高亮文件就不能打开
        return !isDirectoryURL(selectedFileURL)  // 文件夹只展开，不当打开目标
    }

    /// 侧栏、树、打开到哪、底栏。
    var body: some View {
        ZStack {
            BookTheme.deskGradient  // 书桌底
                .ignoresSafeArea()  // 铺满 sheet

            VStack(spacing: 14) {  // 顶栏、中区、目标、底栏
                header  // 标题和关闭
                HStack(alignment: .top, spacing: 12) {  // 左根列表、右树
                    sessionSidebar  // 已打开根
                    treePanel  // 当前根的树
                }
                targetPicker  // 打开到原文/译文/讲解
                footer  // 文件名和打开
            }
            .padding(22)  // sheet 内边
        }
        .frame(width: 760, height: 640)  // 固定尺寸，避免树把窗撑破
        .onAppear {  // 首次进入先同步高亮
            syncSelectionForCurrentSession()  // 切根时高亮落到该树里的文件
        }
        .onChange(of: selectedSession?.id) { _ in  // 换根就重同步，不跨树留旧 URL
            syncSelectionForCurrentSession()  // 切根时高亮落到该树里的文件
        }
        .id(styleManager.revision)  // 字体变整页重建
    }

    /// 标题、根数量、关闭。
    private var header: some View {
        HStack(spacing: 12) {  // 图标、标题、关闭
            ZStack {
                Circle()  // 文件夹徽标底
                    .fill(BookTheme.chromeOverlay.opacity(0.08))  // 浅底，不抢金标
                    .frame(width: 42, height: 42)  // 和标题行齐高
                Image(systemName: "folder.fill")  // 目录语义
                    .font(.system(size: 18))  // 徽标尺寸
                    .foregroundStyle(BookTheme.goldSoft)  // 软金，和书桌一致
            }

            VStack(alignment: .leading, spacing: 3) {  // 标题 + 根数量
                Text(BookL10n.string("directory.title"))  // 目录浏览器标题
                    .font(BookTheme.titleFont)  // 页标题字
                    .foregroundStyle(BookTheme.ink)  // 文件夹名主墨
                Text(BookL10n.format("directory.summary", sessions.count))  // 已打开几个根
                    .font(BookTheme.captionFont)  // 次要操作
                    .foregroundStyle(BookTheme.inkMuted)  // 弱墨
            }

            Spacer(minLength: 0)  // 把关闭推到右边

            Button(action: onDismiss) {  // 只关 sheet
                Image(systemName: "xmark.circle.fill")  // 关
                    .font(.system(size: 20))  // 点按面积
                    .foregroundStyle(BookTheme.inkMuted.opacity(0.55))  // 弱化
            }
            .buttonStyle(.plain)  // 不要系统默认凸起
            .help(BookL10n.string("directory.help.close"))  // 关闭说明
        }
    }

    /// 已打开根目录列表，加号再加一个。
    private var sessionSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {  // 小标题 + 列表
            HStack {  // 「已打开」和加号
                Text(BookL10n.string("directory.opened"))  // 侧栏区标题
                    .font(BookTheme.labelFont)  // 区标题字
                    .foregroundStyle(BookTheme.inkSecondary)  // 次要墨
                Spacer(minLength: 0)  // 把关闭推到右边
                Button(action: onAddDirectory) {  // 系统选目录，宿主插入 session
                    Image(systemName: "plus.circle.fill")  // 加根
                        .font(.system(size: 16))  // 和标题齐
                        .foregroundStyle(BookTheme.gold)  // 主操作金色
                }
                .buttonStyle(.plain)  // 不要系统默认凸起
                .help(BookL10n.string("directory.help.add"))  // 添加目录说明
            }

            ScrollView {  // 根多时侧栏自滚，不挤树
                VStack(spacing: 4) {  // 根行紧排
                    if sessions.isEmpty {  // 还没加根时的空状态
                        Text(BookL10n.string("directory.emptyList"))  // 提示去点加号
                            .font(BookTheme.captionFont)  // 次要操作
                            .foregroundStyle(BookTheme.inkMuted.opacity(0.7))  // 空状态更弱
                            .multilineTextAlignment(.center)  // 空状态居中
                            .frame(maxWidth: .infinity)  // 撑满侧栏宽
                            .padding(.vertical, 24)  // 空列表也有视觉中心
                    } else {
                        ForEach(sessions) { session in  // 每个根一行
                            sessionRow(session)  // 选中、加载、移除
                        }
                    }
                }
            }
        }
        .frame(width: 188)  // 侧栏固定宽，树吃剩余
        .padding(12)  // 页内边
        .bookPage(BookTheme.pageRight)  // 右侧页纸色
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))  // 圆角裁切
        .overlay {  // 金边叠在裁切后的页上
            RoundedRectangle(cornerRadius: 14, style: .continuous)  // 金边
                .strokeBorder(BookTheme.gold.opacity(0.12), lineWidth: 1)  // 浅金描边
        }
    }

    /// 一个根目录行。
    private func sessionRow(_ session: DirectoryBrowserRootSession) -> some View {
        let isSelected = (selectedSession?.id ?? sessions.first?.id) == session.id  // 和当前树用同一套选中
        return HStack(spacing: 6) {  // 主按钮 + 移除
            Button {
                onSelectSession(session.id)  // 宿主记下，树跟着换
            } label: {
                HStack(spacing: 6) {  // 图标和名紧排
                    if session.isLoading {  // 扫盘未完成，不画旧树
                        ProgressView()  // 扫盘转圈
                            .controlSize(.small)  // 塞进行高
                            .frame(width: 14, height: 14)  // 和文件夹图标同宽
                    } else {
                        Image(systemName: session.loadError == nil ? "folder.fill" : "exclamationmark.folder.fill")  // 失败换感叹号
                            .foregroundStyle(isSelected ? BookTheme.gold : BookTheme.inkMuted)  // 选中金
                    }
                    VStack(alignment: .leading, spacing: 1) {  // 名 + 可选错误
                        Text(session.displayName)  // 最后一级目录名
                            .font(BookTheme.captionFont.weight(isSelected ? .semibold : .regular))  // 选中加粗
                            .foregroundStyle(isSelected ? BookTheme.ink : BookTheme.inkSecondary)  // 选中主墨
                            .lineLimit(1)  // 长名截断
                        if let loadError = session.loadError {  // 权限/不存在写在行下
                            Text(loadError)  // 扫盘失败原文
                                .font(.system(size: 10))  // 错误比名更小
                                .foregroundStyle(BookTheme.vermilion.opacity(0.85))  // 朱红报错
                                .lineLimit(1)  // 长名截断
                        }
                    }
                    Spacer(minLength: 0)  // 把关闭推到右边
                }
                .padding(.horizontal, 8)  // 选中底左右
                .padding(.vertical, 6)  // 选中底上下
                .background {  // 选中底或金胶囊
                    RoundedRectangle(cornerRadius: 8, style: .continuous)  // 侧栏行选中底
                        .fill(isSelected ? BookTheme.selection.opacity(0.35) : Color.clear)  // 和侧栏同一套选中色
                }
            }
            .buttonStyle(.plain)  // 不要系统默认凸起

            Button {
                onRemoveSession(session.id)  // 只去掉会话，磁盘不动
            } label: {
                Image(systemName: "xmark")  // 移除根
                    .font(.system(size: 10, weight: .semibold))  // 小三角
                    .foregroundStyle(BookTheme.inkMuted.opacity(0.55))  // 弱化
                    .padding(6)  // 扩大点按
            }
            .buttonStyle(.plain)  // 不要系统默认凸起
            .help(BookL10n.string("directory.help.remove"))  // 移除说明
        }
    }

    @ViewBuilder
    /// 当前根的目录树；加载失败画错误。
    private var treePanel: some View {
        VStack(alignment: .leading, spacing: 8) {  // 小标题 + 列表
            if let session = selectedSession {  // 有根才画树，否则提示去加
                Text(session.rootURL.path)  // 完整路径，中间截断
                    .font(BookTheme.captionFont)  // 次要操作
                    .foregroundStyle(BookTheme.inkMuted)  // 弱墨
                    .lineLimit(1)  // 长名截断
                    .truncationMode(.middle)  // 留卷名和最后一级

                if session.isLoading {  // 扫盘未完成，不画旧树
                    Spacer(minLength: 0)  // 把关闭推到右边
                    HStack {  // 「已打开」和加号
                        Spacer()  // 把加载/错误推到竖向中间
                        VStack(spacing: 10) {  // 转圈和加载文案
                            ProgressView()  // 扫盘转圈
                            Text(BookL10n.string("directory.loading"))  // 加载中
                                .font(BookTheme.captionFont)  // 次要操作
                                .foregroundStyle(BookTheme.inkMuted)  // 弱墨
                        }
                        Spacer()  // 把加载/错误推到竖向中间
                    }
                    Spacer(minLength: 0)  // 把关闭推到右边
                } else if let loadError = session.loadError {  // 失败只露错误，不露半棵树
                    Spacer(minLength: 0)  // 把关闭推到右边
                    Text(loadError)  // 扫盘失败原文
                        .font(BookTheme.captionFont)  // 次要操作
                        .foregroundStyle(BookTheme.vermilion)  // 朱红，和侧栏错误一致
                        .frame(maxWidth: .infinity, alignment: .center)  // 错误居中
                    Spacer(minLength: 0)  // 把关闭推到右边
                } else if let tree = session.tree {  // 扫完才铺扁平行
                    ScrollView {  // 根多时侧栏自滚，不挤树
                        LazyVStack(alignment: .leading, spacing: 2) {  // 只画可见行
                            ForEach(  // 按展开集铺可见行
                                DirectoryTreeFlatRows.visibleRows(  // 按 expandedPaths 展开
                                    from: tree,  // 当前根
                                    expandedPaths: session.expandedPaths  // 哪些文件夹是张开的
                                ),
                                id: \.node.id  // 路径当身份
                            ) { item in  // 扁平行：节点 + 深度
                                treeRow(item.node, depth: item.depth, sessionID: session.id)  // 文件夹展开，文件选中
                            }
                        }
                        .padding(.vertical, 4)  // 树顶底一点气
                    }
                } else {
                    Spacer(minLength: 0)  // 把关闭推到右边
                    Text(BookL10n.string("directory.empty"))  // 根在但没有可见文件
                        .font(BookTheme.captionFont)  // 次要操作
                        .foregroundStyle(BookTheme.inkMuted)  // 弱墨
                        .frame(maxWidth: .infinity, alignment: .center)  // 错误居中
                    Spacer(minLength: 0)  // 把关闭推到右边
                }
            } else {
                Spacer(minLength: 0)  // 把关闭推到右边
                Text(BookL10n.string("directory.addPrompt"))  // 还没加任何根
                    .font(BookTheme.captionFont)  // 次要操作
                    .foregroundStyle(BookTheme.inkMuted)  // 弱墨
                    .frame(maxWidth: .infinity, alignment: .center)  // 错误居中
                Spacer(minLength: 0)  // 把关闭推到右边
            }
        }
        .padding(14)  // 树页内边
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)  // 吃掉中区剩余
        .bookPage(BookTheme.pageLeft)  // 左侧页纸色，和侧栏对仗
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))  // 圆角裁切
        .overlay {  // 金边叠在裁切后的页上
            RoundedRectangle(cornerRadius: 14, style: .continuous)  // 金边
                .strokeBorder(BookTheme.gold.opacity(0.14), lineWidth: 1)  // 比侧栏略亮一点的金边
        }
    }

    @ViewBuilder
    /// 树节点。depth 缩进。
    private func treeRow(_ node: DirectoryTreeNode, depth: Int, sessionID: UUID) -> some View {
        let indent = CGFloat(depth) * 16  // 一层 16pt，和 chevron 齐
        if node.isDirectory {  // 点文件夹只展开，不打开
            let isExpanded = selectedSession?.expandedPaths.contains(node.id) == true  // 路径在集合里才算张开
            Button {
                onToggleExpanded(sessionID, node.id)  // 宿主改 expandedPaths，树重铺
            } label: {
                HStack(spacing: 6) {  // 图标和名紧排
                    Color.clear.frame(width: indent)  // 用透明占位缩进，避免 Spacer 吃掉
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")  // 张开朝下
                        .font(.system(size: 10, weight: .semibold))  // 小三角
                        .foregroundStyle(BookTheme.inkMuted.opacity(0.7))  // 空状态更弱
                        .frame(width: 12)  // 有无 chevron 齐列
                    Image(systemName: "folder.fill")  // 目录语义
                        .foregroundStyle(BookTheme.gold.opacity(0.85))  // 文件夹金
                    Text(node.name)  // 这一级名，不用全路径
                        .font(BookTheme.captionFont)  // 次要操作
                        .foregroundStyle(BookTheme.ink)  // 文件夹名主墨
                        .lineLimit(1)  // 长名截断
                    Spacer(minLength: 0)  // 把关闭推到右边
                }
                .padding(.horizontal, 4)  // 行左右
                .padding(.vertical, 3)  // 紧行高
            }
            .buttonStyle(.plain)  // 不要系统默认凸起
        } else {
            let isSelected = selectedFileURL == node.url  // 和底栏打开用同一个 URL
            Button {
                selectedFileURL = node.url  // 只改高亮，不立刻打开
            } label: {
                HStack(spacing: 6) {  // 图标和名紧排
                    Color.clear.frame(width: indent + 18)  // 对齐到文件夹名，避开 chevron 列
                    Image(systemName: "doc.text")  // 文件，不是文件夹
                        .foregroundStyle(isSelected ? BookTheme.gold : BookTheme.inkMuted)  // 选中金
                    Text(node.name)  // 这一级名，不用全路径
                        .font(BookTheme.captionFont)  // 次要操作
                        .foregroundStyle(isSelected ? BookTheme.ink : BookTheme.inkSecondary)  // 选中主墨
                        .lineLimit(1)  // 长名截断
                    Spacer(minLength: 0)  // 把关闭推到右边
                }
                .padding(.horizontal, 4)  // 行左右
                .padding(.vertical, 3)  // 紧行高
                .background {  // 选中底或金胶囊
                    RoundedRectangle(cornerRadius: 6, style: .continuous)  // 文件行选中底
                        .fill(isSelected ? BookTheme.selection.opacity(0.35) : Color.clear)  // 和侧栏同一套选中色
                }
            }
            .buttonStyle(.plain)  // 不要系统默认凸起
        }
    }

    /// 打开到原文、译文或讲解。
    private var targetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {  // 小标题 + 列表
            Text(BookL10n.string("directory.openTarget"))  // 打开到哪一栏
                .font(BookTheme.labelFont)  // 区标题字
                .foregroundStyle(BookTheme.inkSecondary)  // 次要墨

            HStack(spacing: 8) {  // 打开目标胶囊一行
                ForEach(DirectoryFileOpenTarget.allCases) { target in  // 原文/译文/讲解各一粒
                    targetButton(target)  // 写 openTarget，打开时才用
                }
            }
        }
    }

    /// 打开到原文/译文/讲解。
    private func targetButton(_ target: DirectoryFileOpenTarget) -> some View {
        let isSelected = openTarget == target  // 和将要打开的栏一致
        return Button {  // 只改目标，不打开
            openTarget = target  // 下次打开用这个栏
        } label: {
            HStack(spacing: 6) {  // 图标和名紧排
                Image(systemName: target.icon)  // 栏图标
                Text(target.displayName)  // 栏短标题
                    .font(BookTheme.captionFont.weight(.medium))  // 胶囊字
            }
            .foregroundStyle(isSelected ? BookTheme.buttonProminentText : BookTheme.ink)  // 选中反白
            .padding(.horizontal, 12)  // 胶囊左右
            .padding(.vertical, 7)  // 胶囊高度
            .frame(maxWidth: .infinity)  // 撑满侧栏宽
            .background {  // 选中底或金胶囊
                Capsule()  // 目标粒形状
                    .fill(isSelected ? AnyShapeStyle(BookTheme.gold.opacity(0.9)) : AnyShapeStyle(BookTheme.buttonFill))  // 选中金底
                    .overlay {  // 金边叠在裁切后的页上
                        Capsule()  // 目标粒形状
                            .strokeBorder(  // 胶囊描边
                                isSelected ? BookTheme.gold.opacity(0.5) : BookTheme.buttonBorder,  // 选中金边
                                lineWidth: 1  // 细边
                            )
                    }
            }
        }
        .buttonStyle(.plain)  // 不要系统默认凸起
        .help(target.help)  // 这一栏打开后干什么
    }

    /// 当前文件名、关闭、打开。
    private var footer: some View {
        HStack(spacing: 10) {  // 底栏：文件名、关、开
            if let selectedFileURL, selectedIsFile {  // 有文件才显示名，文件夹当没选
                Text(selectedFileURL.lastPathComponent)  // 底栏只露文件名
                    .font(BookTheme.captionFont)  // 次要操作
                    .foregroundStyle(BookTheme.inkMuted)  // 弱墨
                    .lineLimit(1)  // 长名截断
                    .truncationMode(.middle)  // 留卷名和最后一级
            } else {
                Text(BookL10n.string("directory.pickFile"))  // 还没选文件
                    .font(BookTheme.captionFont)  // 次要操作
                    .foregroundStyle(BookTheme.inkMuted.opacity(0.7))  // 空状态更弱
            }

            Spacer(minLength: 0)  // 把关闭推到右边

            Button(BookL10n.string("action.close"), action: onDismiss)  // 关，不打开
                .buttonStyle(.plain)  // 不要系统默认凸起
                .font(BookTheme.captionFont)  // 次要操作
                .foregroundStyle(BookTheme.inkMuted)  // 弱墨
                .padding(.horizontal, 14)  // 关闭按钮宽
                .padding(.vertical, 7)  // 胶囊高度

            Button(BookL10n.string("action.open")) {  // 打开当前高亮文件
                openSelectedFile()  // 有文件才回调宿主
            }
            .buttonStyle(.plain)  // 不要系统默认凸起
            .font(BookTheme.captionFont.weight(.semibold))  // 主操作加粗
            .foregroundStyle(BookTheme.buttonProminentText)  // 金底反白
            .padding(.horizontal, 18)  // 主按钮更宽
            .padding(.vertical, 7)  // 胶囊高度
            .background {  // 选中底或金胶囊
                Capsule()  // 目标粒形状
                    .fill(BookTheme.gold.opacity(selectedIsFile ? 0.92 : 0.35))  // 没选文件金底淡掉
            }
            .disabled(!selectedIsFile)  // 文件夹或空选点不了
        }
    }

    /// 当前高亮文件按默认 target 打开。
    private func openSelectedFile() {
        guard let url = selectedFileURL, selectedIsFile else { return }  // 没有可打开文件就静默
        onOpen(url, openTarget)  // 交给宿主按目标栏加载
    }

    /// 切根时选中项跟着变。
    private func syncSelectionForCurrentSession() {
        guard let tree = selectedSession?.tree else {  // 根还在加载或失败，清高亮
            selectedFileURL = nil  // 避免打开上一棵树的文件
            return  // 已经有合法高亮或没有可打开文件
        }
        if let selectedFileURL,  // 当前高亮还在这棵树就留着
           fileExistsInTree(selectedFileURL, tree: tree) {  // 路径还在才保持
            return  // 已经有合法高亮或没有可打开文件
        }
        selectedFileURL = firstFileURL(in: tree)  // 否则落到第一份文本，方便直接打开
    }

    /// 树里还有这个 URL 才保持选中。
    private func fileExistsInTree(_ url: URL, tree: DirectoryTreeNode) -> Bool {
        if tree.url == url, !tree.isDirectory { return true }  // 命中文件节点
        for child in tree.children ?? [] {  // 空 children 当没有子
            if fileExistsInTree(url, tree: child) { return true }  // 深搜
        }
        return false  // 这棵树没有该 URL
    }

    /// 空选时落到第一份文本。
    private func firstFileURL(in node: DirectoryTreeNode) -> URL? {
        if !node.isDirectory { return node.url }  // 先序第一份文件
        for child in node.children ?? [] {  // 空 children 当没有子
            if let url = firstFileURL(in: child) { return url }  // 子树里碰到文件就用
        }
        return nil  // 整棵都是空文件夹
    }

    /// 用资源值，不靠有没有扩展名。
    private func isDirectoryURL(_ url: URL) -> Bool {
        var isDirectory = ObjCBool(false)  // 资源值出口，不看扩展名
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue  // 不存在或是文件都算 false
    }
}

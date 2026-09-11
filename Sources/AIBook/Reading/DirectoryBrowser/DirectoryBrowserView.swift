import SwiftUI

struct DirectoryBrowserView: View {
    let sessions: [DirectoryBrowserRootSession]
    let selectedSessionID: UUID?
    let onSelectSession: (UUID) -> Void
    let onAddDirectory: () -> Void
    let onRemoveSession: (UUID) -> Void
    let onToggleExpanded: (UUID, String) -> Void
    let onOpen: (URL, DirectoryFileOpenTarget) -> Void
    let onDismiss: () -> Void

    @ObservedObject private var styleManager = BookStyleManager.shared
    @State private var selectedFileURL: URL?
    @State private var openTarget: DirectoryFileOpenTarget = .original

    private var selectedSession: DirectoryBrowserRootSession? {
        guard let selectedSessionID else { return sessions.first }
        return sessions.first { $0.id == selectedSessionID } ?? sessions.first
    }

    private var selectedIsFile: Bool {
        guard let selectedFileURL else { return false }
        return !isDirectoryURL(selectedFileURL)
    }

    var body: some View {
        ZStack {
            BookTheme.deskGradient
                .ignoresSafeArea()

            VStack(spacing: 14) {
                header
                HStack(alignment: .top, spacing: 12) {
                    sessionSidebar
                    treePanel
                }
                targetPicker
                footer
            }
            .padding(22)
        }
        .frame(width: 760, height: 640)
        .onAppear {
            syncSelectionForCurrentSession()
        }
        .onChange(of: selectedSession?.id) { _ in
            syncSelectionForCurrentSession()
        }
        .id(styleManager.revision)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(BookTheme.chromeOverlay.opacity(0.08))
                    .frame(width: 42, height: 42)
                Image(systemName: "folder.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(BookTheme.goldSoft)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("目录浏览")
                    .font(BookTheme.titleFont)
                    .foregroundStyle(BookTheme.ink)
                Text("已记住 \(sessions.count) 个目录，可继续添加并在其间切换")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            }

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(BookTheme.inkMuted.opacity(0.55))
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
    }

    private var sessionSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("已打开目录")
                    .font(BookTheme.labelFont)
                    .foregroundStyle(BookTheme.inkSecondary)
                Spacer(minLength: 0)
                Button(action: onAddDirectory) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(BookTheme.gold)
                }
                .buttonStyle(.plain)
                .help("添加目录")
            }

            ScrollView {
                VStack(spacing: 4) {
                    if sessions.isEmpty {
                        Text("暂无目录\n点击 + 添加")
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.inkMuted.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(sessions) { session in
                            sessionRow(session)
                        }
                    }
                }
            }
        }
        .frame(width: 188)
        .padding(12)
        .bookPage(BookTheme.pageRight)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(BookTheme.gold.opacity(0.12), lineWidth: 1)
        }
    }

    private func sessionRow(_ session: DirectoryBrowserRootSession) -> some View {
        let isSelected = (selectedSession?.id ?? sessions.first?.id) == session.id
        return HStack(spacing: 6) {
            Button {
                onSelectSession(session.id)
            } label: {
                HStack(spacing: 6) {
                    if session.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: session.loadError == nil ? "folder.fill" : "exclamationmark.folder.fill")
                            .foregroundStyle(isSelected ? BookTheme.gold : BookTheme.inkMuted)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.displayName)
                            .font(BookTheme.captionFont.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? BookTheme.ink : BookTheme.inkSecondary)
                            .lineLimit(1)
                        if let loadError = session.loadError {
                            Text(loadError)
                                .font(.system(size: 10))
                                .foregroundStyle(BookTheme.vermilion.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? BookTheme.selection.opacity(0.35) : Color.clear)
                }
            }
            .buttonStyle(.plain)

            Button {
                onRemoveSession(session.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(BookTheme.inkMuted.opacity(0.55))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help("从列表移除")
        }
    }

    @ViewBuilder
    private var treePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let session = selectedSession {
                Text(session.rootURL.path)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if session.isLoading {
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("正在读取目录…")
                                .font(BookTheme.captionFont)
                                .foregroundStyle(BookTheme.inkMuted)
                        }
                        Spacer()
                    }
                    Spacer(minLength: 0)
                } else if let loadError = session.loadError {
                    Spacer(minLength: 0)
                    Text(loadError)
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.vermilion)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer(minLength: 0)
                } else if let tree = session.tree {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(
                                DirectoryTreeFlatRows.visibleRows(
                                    from: tree,
                                    expandedPaths: session.expandedPaths
                                ),
                                id: \.node.id
                            ) { item in
                                treeRow(item.node, depth: item.depth, sessionID: session.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Spacer(minLength: 0)
                    Text("目录为空")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer(minLength: 0)
                }
            } else {
                Spacer(minLength: 0)
                Text("请添加一个目录")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .bookPage(BookTheme.pageLeft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(BookTheme.gold.opacity(0.14), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func treeRow(_ node: DirectoryTreeNode, depth: Int, sessionID: UUID) -> some View {
        let indent = CGFloat(depth) * 16
        if node.isDirectory {
            let isExpanded = selectedSession?.expandedPaths.contains(node.id) == true
            Button {
                onToggleExpanded(sessionID, node.id)
            } label: {
                HStack(spacing: 6) {
                    Color.clear.frame(width: indent)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(BookTheme.inkMuted.opacity(0.7))
                        .frame(width: 12)
                    Image(systemName: "folder.fill")
                        .foregroundStyle(BookTheme.gold.opacity(0.85))
                    Text(node.name)
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
            }
            .buttonStyle(.plain)
        } else {
            let isSelected = selectedFileURL == node.url
            Button {
                selectedFileURL = node.url
            } label: {
                HStack(spacing: 6) {
                    Color.clear.frame(width: indent + 18)
                    Image(systemName: "doc.text")
                        .foregroundStyle(isSelected ? BookTheme.gold : BookTheme.inkMuted)
                    Text(node.name)
                        .font(BookTheme.captionFont)
                        .foregroundStyle(isSelected ? BookTheme.ink : BookTheme.inkSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? BookTheme.selection.opacity(0.35) : Color.clear)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var targetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("打开到")
                .font(BookTheme.labelFont)
                .foregroundStyle(BookTheme.inkSecondary)

            HStack(spacing: 8) {
                ForEach(DirectoryFileOpenTarget.allCases) { target in
                    targetButton(target)
                }
            }
        }
    }

    private func targetButton(_ target: DirectoryFileOpenTarget) -> some View {
        let isSelected = openTarget == target
        return Button {
            openTarget = target
        } label: {
            HStack(spacing: 6) {
                Image(systemName: target.icon)
                Text(target.displayName)
                    .font(BookTheme.captionFont.weight(.medium))
            }
            .foregroundStyle(isSelected ? BookTheme.buttonProminentText : BookTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background {
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(BookTheme.gold.opacity(0.9)) : AnyShapeStyle(BookTheme.buttonFill))
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                isSelected ? BookTheme.gold.opacity(0.5) : BookTheme.buttonBorder,
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .help(target.help)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let selectedFileURL, selectedIsFile {
                Text(selectedFileURL.lastPathComponent)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("请选择一个文本文件")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted.opacity(0.7))
            }

            Spacer(minLength: 0)

            Button("关闭", action: onDismiss)
                .buttonStyle(.plain)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)

            Button("打开") {
                openSelectedFile()
            }
            .buttonStyle(.plain)
            .font(BookTheme.captionFont.weight(.semibold))
            .foregroundStyle(BookTheme.buttonProminentText)
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(BookTheme.gold.opacity(selectedIsFile ? 0.92 : 0.35))
            }
            .disabled(!selectedIsFile)
        }
    }

    private func openSelectedFile() {
        guard let url = selectedFileURL, selectedIsFile else { return }
        onOpen(url, openTarget)
    }

    private func syncSelectionForCurrentSession() {
        guard let tree = selectedSession?.tree else {
            selectedFileURL = nil
            return
        }
        if let selectedFileURL,
           fileExistsInTree(selectedFileURL, tree: tree) {
            return
        }
        selectedFileURL = firstFileURL(in: tree)
    }

    private func fileExistsInTree(_ url: URL, tree: DirectoryTreeNode) -> Bool {
        if tree.url == url, !tree.isDirectory { return true }
        for child in tree.children ?? [] {
            if fileExistsInTree(url, tree: child) { return true }
        }
        return false
    }

    private func firstFileURL(in node: DirectoryTreeNode) -> URL? {
        if !node.isDirectory { return node.url }
        for child in node.children ?? [] {
            if let url = firstFileURL(in: child) { return url }
        }
        return nil
    }

    private func isDirectoryURL(_ url: URL) -> Bool {
        var isDirectory = ObjCBool(false)
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}

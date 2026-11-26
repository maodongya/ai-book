import SwiftUI

/// 设计稿底栏：原文、讲解、翻译、阅读。设置走右上角「更多」。
struct IOSBottomTabBar: View {
    @ObservedObject var shell: IOSShellModel
    @ObservedObject var document: IOSDocument
    @State private var confirmLeaveSource = false
    @State private var pendingPage: IOSPage?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(IOSPage.tabBarOrder) { page in
                tabButton(page)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .iosPanelChrome(edge: .top)
        .confirmationDialog(
            BookL10n.string("alert.discard.title"),
            isPresented: $confirmLeaveSource,
            titleVisibility: .visible
        ) {
            Button(BookL10n.string("alert.discard.confirm"), role: .destructive) {
                if let pendingPage {
                    document.dirty = false
                    go(to: pendingPage)
                }
                pendingPage = nil
            }
            Button(BookL10n.string("alert.cancel"), role: .cancel) {
                pendingPage = nil
            }
        }
    }

    private func tabButton(_ page: IOSPage) -> some View {
        let selected = shell.page == page
        return Button {
            attemptGo(to: page)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: page.tabSymbol)
                    .font(.body)
                Text(BookL10n.string(page.titleKey))
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(selected ? IOSPaper.ink : IOSPaper.inkMuted)
        }
        .buttonStyle(.plain)
        .disabled(page == .reading && !document.hasSource)
        .accessibilityIdentifier("ios.tab.\(page.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func attemptGo(to page: IOSPage) {
        if shell.page == .source, page != .source, document.dirty {
            pendingPage = page
            confirmLeaveSource = true
            return
        }
        go(to: page)
    }

    private func go(to page: IOSPage) {
        switch page {
        case .reading:
            guard document.hasSource else { return }
            shell.enterReading()
        default:
            shell.select(page)
        }
    }
}
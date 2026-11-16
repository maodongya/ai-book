import SwiftUI

/// 上架前把 `docs/产品/隐私政策.md` 放到公开网页，把网址写在这里，并填进 App Store Connect。
enum PrivacyPolicy {
    static let publicURL: URL? = nil
}

/// 应用内隐私说明。正文跟界面语言走；公开网址另存，空则提示还没发布。
struct PrivacyPolicyView: View {
    @ObservedObject private var styleManager = BookStyleManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let _ = settings.localizationRevision
        let _ = styleManager.revision
        ZStack {
            BookTheme.deskGradient
                .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Text(BookL10n.string("privacy.policy.title"))
                        .font(BookTheme.titleFont)
                        .foregroundStyle(BookTheme.goldSoft)
                    Spacer()
                    if let url = PrivacyPolicy.publicURL {
                        Link(url.absoluteString, destination: url)
                            .font(BookTheme.captionFont)
                            .foregroundStyle(BookTheme.goldSoft)
                    }
                    BookActionButton(title: BookL10n.string("action.done"), icon: "checkmark", isProminent: true) {
                        dismiss()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(BookTheme.leatherGradient)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(OutboundNotice.reading(settings: settings))
                            .font(BookTheme.bodyFont)
                            .foregroundStyle(BookTheme.ink)
                        paragraph("privacy.policy.lead")
                        paragraph("privacy.policy.thirdParty")
                        paragraph("privacy.policy.audio")
                        paragraph("privacy.mic.purpose")
                        paragraph("privacy.speech.purpose")
                        paragraph("privacy.policy.local")
                        if PrivacyPolicy.publicURL == nil {
                            paragraph("privacy.policy.urlMissing")
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: 680, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .bookPage(BookTheme.pageLeft)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(24)
        }
        .frame(minWidth: 720, minHeight: 560)
    }

    private func paragraph(_ key: String) -> some View {
        Text(BookL10n.string(key))
            .font(BookTheme.bodyFont)
            .foregroundStyle(BookTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

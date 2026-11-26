import SwiftUI

/// 说明书正文。按当前界面语言读打包资源，与 Mac 同一套 BookUserManual。
struct IOSUserManualView: View {
  var body: some View {
    ScrollView {
      Text(BookUserManual.loadMarkdown())
        .font(IOSPaper.readingFont)
        .foregroundStyle(IOSPaper.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
    .background(IOSPaper.page)
    .navigationTitle(BookL10n.string("help.manual"))
    .navigationBarTitleDisplayMode(.inline)
  }
}

/// 隐私说明。正文走目录，与 Mac PrivacyPolicyView 同一组 key。
struct IOSPrivacyPolicyView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        if let url = PrivacyPolicy.publicURL {
          Link(destination: url) {
            Text(url.absoluteString)
              .font(IOSPaper.readingFont)
              .foregroundStyle(IOSPaper.ink)
          }
        }
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
      .padding()
    }
    .background(IOSPaper.page)
    .navigationTitle(BookL10n.string("privacy.policy.title"))
    .navigationBarTitleDisplayMode(.inline)
  }

  private func paragraph(_ key: String) -> some View {
    Text(BookL10n.string(key))
      .font(IOSPaper.readingFont)
      .foregroundStyle(IOSPaper.ink)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
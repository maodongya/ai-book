import SwiftUI

struct CursorConfigPanel: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var draftAPIKey = ""
    @State private var showAPIKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .foregroundStyle(BookTheme.gold)
                Text("Cursor API Key（可选）")
                    .font(BookTheme.labelFont)
                    .foregroundStyle(BookTheme.ink)
            }

            if settings.isCursorRunnable {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("cursor-bridge 与 API Key 已就绪，可使用 Cursor 本地对话")
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkSecondary)
                }
            } else if !settings.isCursorBridgeReady {
                Text(settings.cursorBridgeStatusMessage)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            } else if settings.isLLMConfigured {
                Text("未填写 Cursor API Key。右页将自动使用已配置的大模型，填写 Key 后可切换为 Cursor 本地。")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkSecondary)
            } else {
                Text("请填写 Cursor API Key，或先配置一个大模型作为进化后端。")
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            }

            HStack(spacing: 8) {
                Group {
                    if showAPIKey {
                        TextField("cursor_...", text: $draftAPIKey)
                    } else {
                        SecureField("cursor_...", text: $draftAPIKey)
                    }
                }
                .textFieldStyle(.plain)
                .font(BookTheme.bodyFont)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(BookTheme.pageEdge, lineWidth: 1)
                        }
                }

                Button {
                    showAPIKey.toggle()
                } label: {
                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                        .foregroundStyle(BookTheme.inkMuted)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button("保存 Key") {
                    settings.saveCursorAPIKey(draftAPIKey)
                }
                .buttonStyle(.plain)
                .font(BookTheme.labelFont)
                .foregroundStyle(BookTheme.leatherShadow)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule().fill(BookTheme.gold)
                }
                .disabled(draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("从环境变量读取") {
                    settings.refreshCursorAPIKeyFromSources()
                    draftAPIKey = settings.effectiveCursorAPIKey
                }
                .buttonStyle(.plain)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)

                Spacer()
            }

            Text("本地桥接通常无需 Key；若需云端能力，可在 Dashboard → Integrations 获取，或写入 ai-book/cursor.local.env。")
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.inkMuted)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BookTheme.selection.opacity(0.35))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(BookTheme.gold.opacity(0.35), lineWidth: 1)
                }
        }
        .onAppear {
            settings.refreshCursorAPIKeyFromSources()
            draftAPIKey = settings.effectiveCursorAPIKey
        }
    }
}

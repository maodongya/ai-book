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
                Text(BookL10n.string("cursor.apiKeyOptional"))
                    .font(BookTheme.labelFont)
                    .foregroundStyle(BookTheme.ink)
            }

            if settings.isCursorRunnable {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(BookL10n.string("cursor.readyBridge"))
                        .font(BookTheme.captionFont)
                        .foregroundStyle(BookTheme.inkSecondary)
                }
            } else if !settings.isCursorBridgeReady {
                Text(settings.cursorBridgeStatusMessage)
                    .font(BookTheme.captionFont)
                    .foregroundStyle(BookTheme.inkMuted)
            } else {
                Text(BookL10n.string("cursor.needKey"))
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
                Button(BookL10n.string("action.saveKey")) {
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

                Button(BookL10n.string("action.loadFromEnv")) {
                    settings.reloadCursorAPIKey()
                    draftAPIKey = settings.effectiveCursorAPIKey
                }
                .buttonStyle(.plain)
                .font(BookTheme.captionFont)
                .foregroundStyle(BookTheme.leather)

                Spacer()
            }

            Text(BookL10n.string("cursor.keyHint"))
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
            settings.reloadCursorAPIKey()
            draftAPIKey = settings.effectiveCursorAPIKey
        }
    }
}

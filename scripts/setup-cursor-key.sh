#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/cursor.local.env"
BUNDLE_ID="com.aibook.reader"
APP_SUPPORT="$HOME/Library/Application Support/AIBook"
KEY_FILE="$APP_SUPPORT/cursor-api-key"

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
  fi
fi

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
  echo "请设置环境变量 CURSOR_API_KEY，或在 $ENV_FILE 中写入 Key。" >&2
  exit 1
fi

mkdir -p "$APP_SUPPORT"
printf '%s' "$CURSOR_API_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

defaults write "$BUNDLE_ID" aiBook.cursorAPIKey "$CURSOR_API_KEY"
defaults write "$BUNDLE_ID" aiBook.explanationSource "Cursor 本地"

echo "已写入 Cursor API Key："
echo "  - $KEY_FILE"
echo "  - UserDefaults ($BUNDLE_ID)"

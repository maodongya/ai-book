#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/cursor.local.env"

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

defaults write AIBook aiBook.cursorAPIKey "$CURSOR_API_KEY"
defaults write AIBook aiBook.explanationSource "Cursor 本地"

echo "已写入 AIBook 配置（Cursor 本地模式）。"

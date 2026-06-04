#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/Assets"
BASE="$ASSETS/AppIcon-base-1024.png"
SOURCE="$ASSETS/AppIcon-1024.png"
ICONSET="$ASSETS/AppIcon.iconset"
ICNS="$ASSETS/AppIcon.icns"
COMPOSE="$ROOT/scripts/compose-icon-label.swift"

if [[ ! -f "$BASE" ]]; then
  if [[ -f "$SOURCE" ]]; then
    cp "$SOURCE" "$BASE"
  else
    echo "Error: $BASE not found. Add a 1024x1024 PNG first." >&2
    exit 1
  fi
fi

echo "==> Adding ai-book label..."
swift "$COMPOSE" "$BASE" "$SOURCE"

if [[ ! -f "$SOURCE" ]]; then
  echo "Error: failed to compose $SOURCE" >&2
  exit 1
fi

mkdir -p "$ICONSET"

sips -z 16 16 "$SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$SOURCE" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$ICNS"
echo "Generated $ICNS"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AIBook"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
APP_PATH="$INSTALL_DIR/$APP_NAME.app"
STAGING="$ROOT/.build/$APP_NAME.app"

echo "==> Building $APP_NAME (release)..."
cd "$ROOT"
swift build -c release

ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
  BINARY="$ROOT/.build/arm64-apple-macosx/release/$APP_NAME"
else
  BINARY="$ROOT/.build/x86_64-apple-macosx/release/$APP_NAME"
fi

if [[ ! -f "$BINARY" ]]; then
  BINARY="$(find "$ROOT/.build" -type f -name "$APP_NAME" -perm +111 ! -path '*/debug/*' | head -n 1)"
fi

if [[ ! -f "$BINARY" ]]; then
  echo "Error: release binary not found." >&2
  exit 1
fi

echo "==> Creating app bundle..."
rm -rf "$STAGING"
mkdir -p "$STAGING/Contents/MacOS"
mkdir -p "$STAGING/Contents/Resources"

cp "$BINARY" "$STAGING/Contents/MacOS/$APP_NAME"
chmod +x "$STAGING/Contents/MacOS/$APP_NAME"

if [[ ! -f "$ROOT/Assets/AppIcon.icns" ]]; then
  echo "==> Generating app icon..."
  "$ROOT/scripts/generate-icon.sh"
fi
cp "$ROOT/Assets/AppIcon.icns" "$STAGING/Contents/Resources/AppIcon.icns"
cp "$ROOT/App/Info.plist" "$STAGING/Contents/Info.plist"

if [[ -d "$ROOT/Sources/AIBook/Resources" ]]; then
  cp -R "$ROOT/Sources/AIBook/Resources/." "$STAGING/Contents/Resources/"
fi

if [[ -d "$ROOT/cursor-bridge" ]]; then
  echo "==> Bundling cursor-bridge..."
  BRIDGE_DEST="$STAGING/Contents/Resources/cursor-bridge"
  mkdir -p "$BRIDGE_DEST"
  rsync -a \
    --exclude node_modules/.cache \
    "$ROOT/cursor-bridge/" "$BRIDGE_DEST/"
  if [[ ! -d "$BRIDGE_DEST/node_modules" ]]; then
    echo "==> Installing cursor-bridge dependencies..."
    (cd "$BRIDGE_DEST" && npm install --omit=dev --silent)
  fi
fi

if [[ -d "$ROOT/speech-bridge" ]]; then
  echo "==> Bundling speech-bridge..."
  SPEECH_DEST="$STAGING/Contents/Resources/speech-bridge"
  mkdir -p "$SPEECH_DEST"
  rsync -a \
    --exclude node_modules/.cache \
    "$ROOT/speech-bridge/" "$SPEECH_DEST/"
  if [[ ! -d "$SPEECH_DEST/node_modules" ]]; then
    echo "==> Installing speech-bridge dependencies..."
    (cd "$SPEECH_DEST" && npm install --omit=dev --silent)
  fi
fi

echo "==> Installing to $APP_PATH..."
if [[ -w "$INSTALL_DIR" ]]; then
  rm -rf "$APP_PATH"
  cp -R "$STAGING" "$APP_PATH"
else
  echo "Requesting permission to install into $INSTALL_DIR..."
  sudo rm -rf "$APP_PATH"
  sudo cp -R "$STAGING" "$APP_PATH"
fi

echo "==> Done."
echo "    App: $APP_PATH"
echo "    Launch: open \"$APP_PATH\""

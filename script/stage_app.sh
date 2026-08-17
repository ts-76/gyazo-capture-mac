#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-debug}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRODUCT_NAME="GyazoCapture"
APP_NAME="GyazoCaptureDev"
APP_BUNDLE="$PROJECT_ROOT/dist/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"

swift build -c "$CONFIGURATION" --package-path "$PROJECT_ROOT"
BIN_PATH="$(swift build -c "$CONFIGURATION" --package-path "$PROJECT_ROOT" --show-bin-path)/$PRODUCT_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BIN_PATH" "$APP_MACOS/$APP_NAME"
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.toma7698.GyazoCapture.dev" "$APP_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Gyazo Capture Dev" "$APP_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Gyazo Capture Dev" "$APP_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 gyazocapture-dev" "$APP_CONTENTS/Info.plist"
chmod +x "$APP_MACOS/$APP_NAME"

/usr/bin/codesign --force --sign - --timestamp=none "$APP_BUNDLE"
echo "$APP_BUNDLE"

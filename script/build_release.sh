#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.1.0}"
BUILD_NUMBER="${2:-1}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="GyazoCapture"
RELEASE_ROOT="$PROJECT_ROOT/dist/release"
APP_BUNDLE="$RELEASE_ROOT/$APP_NAME.app"
STAGING_DIR="$RELEASE_ROOT/dmg-root"
DMG_PATH="$PROJECT_ROOT/dist/GyazoCapture-$VERSION.dmg"

rm -rf "$RELEASE_ROOT" "$DMG_PATH" "$DMG_PATH.sha256"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$STAGING_DIR"

swift build -c release --arch arm64 --scratch-path "$PROJECT_ROOT/.build/release-arm64" --package-path "$PROJECT_ROOT"
swift build -c release --arch x86_64 --scratch-path "$PROJECT_ROOT/.build/release-x86_64" --package-path "$PROJECT_ROOT"

ARM_BINARY="$(swift build -c release --arch arm64 --scratch-path "$PROJECT_ROOT/.build/release-arm64" --package-path "$PROJECT_ROOT" --show-bin-path)/$APP_NAME"
X86_BINARY="$(swift build -c release --arch x86_64 --scratch-path "$PROJECT_ROOT/.build/release-x86_64" --package-path "$PROJECT_ROOT" --show-bin-path)/$APP_NAME"
/usr/bin/lipo -create "$ARM_BINARY" "$X86_BINARY" -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
/usr/bin/codesign --force --sign - --timestamp=none "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
/usr/bin/hdiutil create -volname "Gyazo Capture" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"
(
  cd "$(dirname "$DMG_PATH")"
  /usr/bin/shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$DMG_PATH").sha256"
)

echo "$DMG_PATH"

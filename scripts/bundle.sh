#!/bin/bash
# ScreenshotApp を .app バンドルとしてパッケージングする
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_NAME="ScreenshotApp"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "==> Building $APP_NAME..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

echo "==> Creating app bundle..."
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"

cp "$BUILD_DIR/$APP_NAME" "$MACOS/"

# Info.plist を生成（Xcode変数を使わない独立版）
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>ja</string>
    <key>CFBundleDisplayName</key>
    <string>Screenshot</string>
    <key>CFBundleExecutable</key>
    <string>ScreenshotApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.screenshotapp</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ScreenshotApp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>スクリーンショットを撮影するためにアクセスが必要です</string>
</dict>
</plist>
PLIST

echo "==> Done: $APP_BUNDLE"
echo "    Run: open \"$APP_BUNDLE\""

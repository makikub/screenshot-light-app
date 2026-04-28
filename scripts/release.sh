#!/bin/bash
# ScreenshotApp リリースビルド + DMG 作成 + Apple 公証
# 使い方: bash scripts/release.sh
#
# 事前準備（1回のみ）:
#   xcrun notarytool store-credentials "notarytool-profile" \
#       --apple-id "<Apple ID>" --team-id "L98U958G2N" --password "<App用パスワード>"
set -euo pipefail

#───────────────────────────────────────────
# 設定
#───────────────────────────────────────────
APP_NAME="ScreenshotApp"
SCHEME="ScreenshotApp"
IDENTITY="Developer ID Application: Masaki Kubota (L98U958G2N)"
TEAM_ID="L98U958G2N"
KEYCHAIN_PROFILE="notarytool-profile"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build/release"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_PATH="$EXPORT_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

#───────────────────────────────────────────
# 0. クリーンアップ
#───────────────────────────────────────────
echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

#───────────────────────────────────────────
# 1. XcodeGen でプロジェクト再生成
#───────────────────────────────────────────
echo "==> Generating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

#───────────────────────────────────────────
# 2. Archive ビルド（Release 構成）
#───────────────────────────────────────────
echo "==> Archiving (Release)..."
xcodebuild archive \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="$IDENTITY" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    ENABLE_HARDENED_RUNTIME=YES \
    | tail -1

#───────────────────────────────────────────
# 3. Archive から .app を取り出し
#───────────────────────────────────────────
echo "==> Exporting app from archive..."
mkdir -p "$EXPORT_DIR"
cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$APP_PATH"

#───────────────────────────────────────────
# 3.5. Sparkle 内部実行ファイルを Developer ID で再署名
#      SwiftPM 配布の Sparkle は ad-hoc 署名のため、
#      公証通過には末端から外側へ depth-first で再署名する必要がある
#───────────────────────────────────────────
SPARKLE_FW="$APP_PATH/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE_FW" ]; then
    echo "==> Re-signing Sparkle internals (depth-first)..."
    SIGN_OPTS=(--force --options=runtime --timestamp --sign "$IDENTITY")

    codesign "${SIGN_OPTS[@]}" "$SPARKLE_FW/Versions/B/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"
    codesign "${SIGN_OPTS[@]}" "$SPARKLE_FW/Versions/B/XPCServices/Downloader.xpc"
    codesign "${SIGN_OPTS[@]}" "$SPARKLE_FW/Versions/B/XPCServices/Installer.xpc/Contents/MacOS/Installer"
    codesign "${SIGN_OPTS[@]}" "$SPARKLE_FW/Versions/B/XPCServices/Installer.xpc"
    codesign "${SIGN_OPTS[@]}" "$SPARKLE_FW/Versions/B/Updater.app/Contents/MacOS/Updater"
    codesign "${SIGN_OPTS[@]}" "$SPARKLE_FW/Versions/B/Updater.app"
    codesign "${SIGN_OPTS[@]}" "$SPARKLE_FW/Versions/B/Autoupdate"
    codesign "${SIGN_OPTS[@]}" "$SPARKLE_FW"

    # 内部を変更したのでアプリ本体も再署名（entitlements を保持）
    codesign "${SIGN_OPTS[@]}" \
        --entitlements "$PROJECT_DIR/ScreenshotApp/ScreenshotApp.entitlements" \
        "$APP_PATH"
fi

#───────────────────────────────────────────
# 4. 署名の検証
#───────────────────────────────────────────
echo "==> Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH"
echo "    Signature OK"

#───────────────────────────────────────────
# 5. DMG 作成
#───────────────────────────────────────────
echo "==> Creating DMG..."
DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGING"

#───────────────────────────────────────────
# 6. DMG に署名
#───────────────────────────────────────────
echo "==> Signing DMG..."
codesign --sign "$IDENTITY" "$DMG_PATH"

#───────────────────────────────────────────
# 7. Apple 公証に提出
#───────────────────────────────────────────
echo "==> Submitting for notarization (this may take a few minutes)..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

#───────────────────────────────────────────
# 8. 公証チケットの埋め込み（Staple）
#───────────────────────────────────────────
echo "==> Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

#───────────────────────────────────────────
# 完了
#───────────────────────────────────────────
echo ""
echo "========================================="
echo "  Done! DMG: $DMG_PATH"
echo "========================================="
echo ""
echo "検証コマンド:"
echo "  spctl --assess --type open --context context:primary-signature -v \"$DMG_PATH\""

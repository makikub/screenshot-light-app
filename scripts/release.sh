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

PLIST="$PROJECT_DIR/ScreenshotApp/Info.plist"
APPCAST="$PROJECT_DIR/appcast.xml"
PRIVATE_KEY_FILE="$PROJECT_DIR/private-key-file"
SIGN_UPDATE="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/bin/sign_update"

# DMG の配信元ベース URL。ローカル検証時は DMG_URL_BASE で上書きできる。
DMG_URL_BASE="${DMG_URL_BASE:-https://github.com/makikub/screenshot-light-app/releases/download}"

#───────────────────────────────────────────
# 0. クリーンアップ
#───────────────────────────────────────────
echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

#───────────────────────────────────────────
# 1. XcodeGen でプロジェクト再生成 + Sparkle 成果物の解決
#    （sign_update を .build/artifacts/sparkle/ に確実に展開させる）
#───────────────────────────────────────────
echo "==> Generating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

if [ ! -x "$SIGN_UPDATE" ]; then
    echo "==> Resolving SwiftPM packages to materialize sign_update..."
    swift package resolve
fi
if [ ! -x "$SIGN_UPDATE" ]; then
    echo "ERROR: sign_update not found at $SIGN_UPDATE" >&2
    exit 1
fi

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
#      --wait は Accepted/Invalid いずれでも exit 0 を返すため、
#      出力をログに残して status を文字列でチェックする
#───────────────────────────────────────────
echo "==> Submitting for notarization (this may take a few minutes)..."
NOTARY_LOG="$BUILD_DIR/notarytool-submit.log"
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait 2>&1 | tee "$NOTARY_LOG"

if ! grep -q "status: Accepted" "$NOTARY_LOG"; then
    echo ""
    echo "==> Notarization did not succeed. Fetching detailed log..."
    SUBMISSION_ID=$(grep -m1 "  id: " "$NOTARY_LOG" | awk '{print $2}')
    if [ -n "$SUBMISSION_ID" ]; then
        echo "    Submission ID: $SUBMISSION_ID"
        xcrun notarytool log "$SUBMISSION_ID" \
            --keychain-profile "$KEYCHAIN_PROFILE"
    else
        echo "    Could not extract submission ID from log."
    fi
    exit 1
fi

#───────────────────────────────────────────
# 8. 公証チケットの埋め込み（Staple）
#      staple 失敗は配布可否に直結しないため警告に留める
#      （DMG 自体は Accepted で配布可能。後日 stapler を単独実行可）
#───────────────────────────────────────────
echo "==> Stapling notarization ticket..."
if ! xcrun stapler staple "$DMG_PATH"; then
    echo ""
    echo "    [WARN] Stapling failed — DMG is still notarized and distributable."
    echo "    Retry later with: xcrun stapler staple \"$DMG_PATH\""
fi

#───────────────────────────────────────────
# 9. appcast.xml に新 item を追記（Sparkle EdDSA 署名）
#      - Info.plist から version を読む
#      - sign_update で edSignature と length を取得
#      - 既存の同 build_number item があれば置換、無ければ追加
#───────────────────────────────────────────
echo "==> Updating appcast.xml..."

SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
DMG_URL="${DMG_URL_BASE}/v${SHORT_VERSION}/${APP_NAME}.dmg"

echo "    version       : $SHORT_VERSION ($BUILD_NUMBER)"
echo "    enclosure URL : $DMG_URL"

# sign_update の出力例: sparkle:edSignature="..." length="..."
SIGN_OUTPUT=$("$SIGN_UPDATE" --ed-key-file "$PRIVATE_KEY_FILE" "$DMG_PATH")
ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
ENCLOSURE_LENGTH=$(echo "$SIGN_OUTPUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p')

if [ -z "$ED_SIGNATURE" ] || [ -z "$ENCLOSURE_LENGTH" ]; then
    echo "ERROR: failed to parse sign_update output: $SIGN_OUTPUT" >&2
    exit 1
fi

PUB_DATE=$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")

SHORT_VERSION="$SHORT_VERSION" \
BUILD_NUMBER="$BUILD_NUMBER" \
DMG_URL="$DMG_URL" \
ED_SIGNATURE="$ED_SIGNATURE" \
ENCLOSURE_LENGTH="$ENCLOSURE_LENGTH" \
PUB_DATE="$PUB_DATE" \
APPCAST="$APPCAST" \
python3 - <<'PYEOF'
import os
import xml.etree.ElementTree as ET

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
DC_NS = "http://purl.org/dc/elements/1.1/"
ET.register_namespace("sparkle", SPARKLE_NS)
ET.register_namespace("dc", DC_NS)

appcast = os.environ["APPCAST"]
short_version = os.environ["SHORT_VERSION"]
build_number = os.environ["BUILD_NUMBER"]
dmg_url = os.environ["DMG_URL"]
ed_signature = os.environ["ED_SIGNATURE"]
enclosure_length = os.environ["ENCLOSURE_LENGTH"]
pub_date = os.environ["PUB_DATE"]

tree = ET.parse(appcast)
root = tree.getroot()
channel = root.find("channel")
if channel is None:
    raise SystemExit("ERROR: <channel> not found in appcast.xml")

# 同 build_number の item を削除（再リリース時の冪等性のため）
for existing in list(channel.findall("item")):
    v = existing.find(f"{{{SPARKLE_NS}}}version")
    if v is not None and v.text == build_number:
        channel.remove(existing)

item = ET.SubElement(channel, "item")
ET.SubElement(item, "title").text = f"Version {short_version}"
ET.SubElement(item, "pubDate").text = pub_date
ET.SubElement(item, f"{{{SPARKLE_NS}}}version").text = build_number
ET.SubElement(item, f"{{{SPARKLE_NS}}}shortVersionString").text = short_version
ET.SubElement(item, f"{{{SPARKLE_NS}}}minimumSystemVersion").text = "14.0"
ET.SubElement(
    item,
    "enclosure",
    {
        "url": dmg_url,
        "type": "application/octet-stream",
        "length": enclosure_length,
        f"{{{SPARKLE_NS}}}edSignature": ed_signature,
    },
)

ET.indent(tree, space="    ")
tree.write(appcast, encoding="utf-8", xml_declaration=True)
PYEOF

echo "    appcast.xml updated."

#───────────────────────────────────────────
# 完了
#───────────────────────────────────────────
echo ""
echo "========================================="
echo "  Done! DMG: $DMG_PATH"
echo "========================================="
echo ""
echo "次のステップ:"
echo "  1. gh release create v${SHORT_VERSION} \"$DMG_PATH\" --title \"v${SHORT_VERSION}\""
echo "  2. git add appcast.xml ScreenshotApp/Info.plist && git commit && git push"
echo ""
echo "検証コマンド:"
echo "  spctl --assess --type open --context context:primary-signature -v \"$DMG_PATH\""

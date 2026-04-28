#!/bin/bash
# project.yml と Info.plist の CFBundleShortVersionString / CFBundleVersion を書き換える
#
# 使い方:
#   bash scripts/bump_version.sh 1.1            # short=1.1、build は現在値+1
#   bash scripts/bump_version.sh 1.1 3          # short=1.1、build=3 を明示
#
# Sparkle は CFBundleVersion（数値）で新旧を判定するため、リリースごとに
# 必ず単調増加させる必要がある。short は表示用なので semver でよい。
#
# project.yml が Single Source of Truth: XcodeGen が Info.plist を再生成する際、
# project.yml の info.properties に書かれていない CFBundle 系キーは
# デフォルト値 (1.0 / 1) で上書きされてしまう。両方を更新することで
# xcodegen 経由でも素のビルドでも正しい値が伝わる。
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 <short_version> [build_number]"
    echo "  example: $0 1.1"
    echo "  example: $0 1.1 5"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PLIST="$PROJECT_DIR/ScreenshotApp/Info.plist"
PROJECT_YML="$PROJECT_DIR/project.yml"

SHORT_VERSION="$1"

if [ $# -eq 2 ]; then
    BUILD_NUMBER="$2"
else
    CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
    BUILD_NUMBER=$((CURRENT_BUILD + 1))
fi

echo "==> Updating versions"
echo "    CFBundleShortVersionString -> $SHORT_VERSION"
echo "    CFBundleVersion            -> $BUILD_NUMBER"

PLIST="$PLIST" PROJECT_YML="$PROJECT_YML" \
SHORT_VERSION="$SHORT_VERSION" BUILD_NUMBER="$BUILD_NUMBER" \
python3 - <<'PYEOF'
import os
import re

short_version = os.environ["SHORT_VERSION"]
build_number = os.environ["BUILD_NUMBER"]

# Info.plist: <key>...</key>\s*<string>VALUE</string> の VALUE のみ置換（順序保存）
plist_path = os.environ["PLIST"]
with open(plist_path, "r", encoding="utf-8") as f:
    text = f.read()

def replace_plist(text, key, value):
    pattern = rf'(<key>{re.escape(key)}</key>\s*<string>)[^<]*(</string>)'
    new_text, n = re.subn(pattern, rf'\g<1>{value}\g<2>', text, count=1)
    if n != 1:
        raise SystemExit(f"ERROR: failed to replace <key>{key}</key> in Info.plist")
    return new_text

text = replace_plist(text, "CFBundleShortVersionString", short_version)
text = replace_plist(text, "CFBundleVersion", build_number)
with open(plist_path, "w", encoding="utf-8") as f:
    f.write(text)

# project.yml: 行頭インデント維持で値だけ置換
yml_path = os.environ["PROJECT_YML"]
with open(yml_path, "r", encoding="utf-8") as f:
    yml = f.read()

def replace_yaml(yml, key, value):
    pattern = rf'(^[ \t]+{re.escape(key)}:[ \t]*")[^"]*(")'
    new_yml, n = re.subn(pattern, rf'\g<1>{value}\g<2>', yml, count=1, flags=re.MULTILINE)
    if n != 1:
        raise SystemExit(f"ERROR: failed to replace {key} in project.yml")
    return new_yml

yml = replace_yaml(yml, "CFBundleShortVersionString", short_version)
yml = replace_yaml(yml, "CFBundleVersion", build_number)
with open(yml_path, "w", encoding="utf-8") as f:
    f.write(yml)
PYEOF

echo "==> Done."

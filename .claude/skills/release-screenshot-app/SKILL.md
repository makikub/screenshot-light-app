---
name: release-screenshot-app
description: ScreenshotApp を Sparkle 自動アップデート対応でリリース。最新リリース調査 → ユーザーに次バージョンを確認 → bump_version.sh → release.sh（DMG/公証/appcast 更新）→ gh release create → git push まで一気通貫。「リリース」「release」「次バージョン出して」「v1.x をリリース」などのトリガーで使用。
---

## コンテキスト（自動収集）

- **現在のブランチ**: !`git branch --show-current`
- **未コミット変更**: !`git status --short`
- **直近コミット**: !`git log --oneline -5`
- **ローカル plist の version**: !`/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" ScreenshotApp/Info.plist 2>/dev/null` (build !`/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" ScreenshotApp/Info.plist 2>/dev/null`)
- **GitHub の最新リリース**: !`gh release view --json tagName,publishedAt --jq '"\(.tagName) (\(.publishedAt))"' 2>/dev/null || echo "(no releases yet)"`
- **appcast の最新 sparkle:version**: !`grep -oE '<sparkle:version>[0-9]+</sparkle:version>' appcast.xml | tail -1`

# Release ScreenshotApp Skill

ScreenshotApp の `bump_version.sh → release.sh → gh release → push` を一気通貫で流す。
`scripts/release.sh` の仕組みは `CLAUDE.md` の **Release Workflow** セクション参照。

## 前提チェック（最初に必ず）

実行前に以下が満たされているか確認する。1つでも欠けたら**中断してユーザーに確認**。

1. **作業ブランチが `main`** で **未コミット変更が無い**こと（コンテキスト出力で判定）
2. `gh auth status` で `repo` スコープがあること
3. `notarytool-profile` キーチェーンプロファイルが登録済みであること
   （`xcrun notarytool history --keychain-profile "notarytool-profile"` がエラーを返さない）
4. `private-key-file` がプロジェクト直下に存在すること

未コミット変更がある場合は AskUserQuestion で「先にコミット」「stash する」「変更を含めてリリース」のどれかをユーザーに選ばせる。

## Step 1: 次バージョンを決める

AskUserQuestion で以下を聞く:

- **次の short version**（例: 1.1 → 1.2 / 1.1 → 1.1.1 / 1.1 → 2.0）
  - 選択肢は現バージョンを基準に「patch / minor / major / 手入力」を提示
- **リリースノートの方針**: `--generate-notes`（コミットから自動生成）で十分か、手入力か

build_number は `bump_version.sh` が自動 +1 するので確認不要。

## Step 2: バージョンバンプ

```bash
bash scripts/bump_version.sh <new_short_version>
```

これで `project.yml` と `ScreenshotApp/Info.plist` の `CFBundleShortVersionString` /
`CFBundleVersion` が同時更新される（XcodeGen の上書き対策）。

差分を `git diff project.yml ScreenshotApp/Info.plist` で確認し、`<new>` / `<build>` の
2 行のみが変わっていることを assert。

## Step 3: release.sh をバックグラウンド実行

公証で数分かかるためバックグラウンドで流し、完了マーカーで待つ:

```bash
# 起動
bash scripts/release.sh 2>&1 | tee /tmp/release-vX.Y.log
```

Bash ツールを `run_in_background: true` で起動し、別途 grep 待機を `run_in_background: true` で立てる:

```bash
until grep -qE "(Done! DMG:|ERROR:|error:|did not succeed|status: Invalid)" /tmp/release-vX.Y.log 2>/dev/null; do sleep 5; done
tail -n 30 /tmp/release-vX.Y.log
```

**完了判定**:
- `Done! DMG: ...` が出れば成功
- `did not succeed` / `status: Invalid` / `ERROR:` が出たら失敗 → CLAUDE.md の
  **Distribution / Notarization Troubleshooting** 表に従って原因切り分け

**成功時の検証** (release.sh が自動でやってくれない部分):
```bash
# ビルド済み app のバージョンが期待通りか
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" build/release/export/ScreenshotApp.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" build/release/export/ScreenshotApp.app/Contents/Info.plist
# appcast の最新 item が期待通りか
tail -n 12 appcast.xml
```

## Step 4: GitHub Release 作成

```bash
gh release create v<new_short_version> build/release/ScreenshotApp.dmg \
    --title "v<new_short_version>" \
    --generate-notes
```

リリースノートを手入力する選択をユーザーがした場合は `--generate-notes` を外して
`--notes "..."` で渡す。

成功すると `https://github.com/makikub/screenshot-light-app/releases/tag/vX.Y` の
URL が返る。これを必ずユーザーに表示。

## Step 5: commit & push

```bash
git add appcast.xml ScreenshotApp/Info.plist project.yml
git commit -m "release: v<new_short_version>"
git push
```

コミットメッセージは `release: v<short>` で固定（CLAUDE.md の commit 規約に従う）。
本文に追加情報があれば 2 段目以降に入れる。

## Step 6: 検証指示

ユーザーに以下を依頼:

> インストール済みのアプリで「アップデートを確認」を押してください。
> "Screenshot vX.Y is now available — you have <旧>" のダイアログが出れば成功です。
> CDN キャッシュで反映されない場合は数分待って再試行してください。

検証結果をユーザーが報告したら、必要に応じて memory に project memory として
「v<X.Y> をリリース、Sparkle 自動更新で配信成功」を保存（次セッション以降の
「最新版は何？」への参照用）。

## 失敗時のリカバリ

| 症状 | 対処 |
|---|---|
| `bump_version.sh` で `failed to replace` | `Info.plist` か `project.yml` のキーが既存パターンと一致しない。手動編集して再試行 |
| 公証 `Invalid` | release.sh が自動で `notarytool log` を出す。`issues[]` を確認 |
| `Sparkle.framework/...not signed with a valid Developer ID` | release.sh の Step 3.5（Sparkle 内部 depth-first 再署名）が走っているか確認 |
| `gh release create` で 422 | 既に同タグが存在。`gh release delete v<X.Y>` で消すか別バージョンに |
| push 後に `You're up to date!` のまま | raw.githubusercontent.com の CDN キャッシュ。最大 5 分待って再試行 |
| アップデートが見えるがインストール失敗 | Console.app で `Sparkle` フィルタ。EdDSA 検証 / Installer.xpc 起動失敗のどちらかを確認 |

## アンチパターン

- `Info.plist` だけ手動編集して `project.yml` を放置 → release.sh の `xcodegen generate`
  で値が消える。**必ず `bump_version.sh` を使う**
- `appcast.xml` の `sparkle:edSignature` を手で書き換える → 署名検証が落ちる。
  必ず `release.sh` を再実行する
- `gh release create` の前に push してしまう → enclosure URL が一時的に 404。
  順序は **release → gh release → commit → push** で固定

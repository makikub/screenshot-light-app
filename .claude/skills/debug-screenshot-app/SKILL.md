---
name: debug-screenshot-app
description: ScreenshotApp の Debug ビルドをローカル実行する手順。/Applications/ にあるリリース版（v1.x、Sparkle 配信版）が起動していれば停止し、Debug ビルド → TCC リセット → 起動 → 動作確認まで実施。「デバッグ」「debug」「動作確認」「ローカル実行」「Debug ビルドを試したい」などのトリガーで使用。
---

## コンテキスト（自動収集）

- **現在のブランチ**: !`git branch --show-current`
- **未コミット変更**: !`git status --short`
- **動作中プロセス**: !`pgrep -lf ScreenshotApp || echo "(なし)"`
- **TCC 画面収録の登録状態**: !`sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT client, allowed FROM access WHERE service='kTCCServiceScreenCapture' AND client LIKE '%screenshot%';" 2>/dev/null || echo "(SQLite 直読不可)"`
- **最新の Debug ビルド成果物**: !`ls -lat ~/Library/Developer/Xcode/DerivedData/ScreenshotApp-*/Build/Products/Debug/ScreenshotApp.app 2>/dev/null | head -1 || echo "(未ビルド)"`

# Debug ScreenshotApp Skill

ローカルで Debug ビルドを動かして動作確認する。
Sparkle 自動アップデート対応のため、リリース版 (`/Applications/ScreenshotApp.app`) と
Debug ビルドは **同じ bundle id (`com.masakikubota.screenshot`)** を共有する。
グローバルホットキー ⌘⇧S が衝突するため、**同時起動は不可**。
片方を必ず停止する運用。

## 前提

- bundle id 分離はしない方針（Carbon の `RegisterEventHotKey` がシステム
  グローバルでキー競合するため、bundle id を分けても HotKey 競合は解けない）
- このため、Debug を試すたびにリリース版を `pkill` で停止する手順が必須

## ワークフロー

### Step 1: 動作中プロセスを停止

リリース版 or 前回の Debug ビルドが残っていれば停止する:

```bash
pkill -f ScreenshotApp
```

`pgrep -f ScreenshotApp` で何も出なくなることを確認してから次に進む。

### Step 2: Debug ビルド

```bash
xcodebuild -project ScreenshotApp.xcodeproj \
    -scheme ScreenshotApp \
    -configuration Debug \
    build
```

出力末尾に `BUILD SUCCEEDED` が出ればOK。失敗時はビルドエラーを修正。

`project.yml` を変更している場合は先に `xcodegen generate` を実行する。

### Step 3: TCC（画面収録権限）リセット

**必須ではない**が、以下の場合は実行する:

- 権限ダイアログの再表示を確認したい（オンボーディング動作確認）
- 前回ビルドのバイナリハッシュと今回が異なり、TCC が認可を引き継がない懸念がある
- 起動後に `screencapture` がエラーで動かない

```bash
tccutil reset ScreenCapture com.masakikubota.screenshot
```

`tccutil` 実行直後に Debug ビルドを起動すると、画面収録の許可ダイアログが
出るので「システム設定で許可」→ アプリを開き直す必要がある。

権限を維持したい場合（連続デバッグ時）はこのステップを**スキップ**してよい。
AskUserQuestion で「TCC をリセットしますか？」を確認する。

### Step 4: Debug ビルドを起動

```bash
open ~/Library/Developer/Xcode/DerivedData/ScreenshotApp-*/Build/Products/Debug/ScreenshotApp.app
```

起動後の確認:

```bash
pgrep -lf ScreenshotApp
# Debug.app のパスが表示されること（/Applications/ ではなく DerivedData 配下）
```

### Step 5: 動作確認

ユーザーに以下を依頼:

- メニューバーに **Screenshot のカメラアイコン**が表示されていること
- ⌘⇧S で領域選択キャプチャが起動すること
- キャプチャ後、フローティングウィンドウに画像が表示され、5種類の
  注釈ツール（矢印・矩形・テキスト・フリーハンド・モザイク）が動作すること
- 改修対象の機能が期待通り動作すること

## デバッグ完了後の戻し方

リリース版に戻す場合:

```bash
pkill -f ScreenshotApp
open /Applications/ScreenshotApp.app
```

## トラブルシュート

| 症状 | 対処 |
|---|---|
| `pgrep -lf ScreenshotApp` で 2 プロセス見える | リリース版と Debug が同居している。`pkill` で全停止 → 起動し直す |
| ⌘⇧S を押しても何も起きない | リリース版が動いていてキー登録を握っているか、TCC 未認可。`pkill` 後に Debug を起動し直す |
| 起動後すぐにクラッシュ | Console.app で `ScreenshotApp` フィルタ。Sparkle 関連なら Developer ID 署名確認 |
| TCC 設定で許可してもダイアログが繰り返し出る | DerivedData のパスが変わるたび TCC の path-bound エントリが切れる。`tccutil reset` で完全リセット |
| Debug 起動後、Sparkle が「アップデートを確認」を勝手に走らせる | Debug ビルドにも `SUFeedURL` が埋まっているため。検証中は手動で押さない。意図せず押した場合、appcast の最新版で DerivedData が上書きされる事故が起きるので注意 |

## アンチパターン

- リリース版を起動したまま `xcodebuild` を実行 → ビルド自体は成功するが、
  **古い DerivedData が `/Applications/` のリリース版に上書きされている可能性**
  があり、起動するとリリース版が上がってきて混乱する。**必ず `pkill` を先に**
- `tccutil reset` を毎回叩く → 都度オンボーディングからやり直しになり開発が遅い。
  権限ダイアログの確認が不要なら**スキップ**してよい
- `open` の前に `pgrep` で確認しないまま起動 → リリース版が前面に出てきて
  「あれ、Debug が起動しない」と勘違いする

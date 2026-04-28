# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# ビルド & 実行（推奨）
xcodebuild -project ScreenshotApp.xcodeproj -scheme ScreenshotApp -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/ScreenshotApp-*/Build/Products/Debug/ScreenshotApp.app

# Xcode プロジェクト再生成（project.yml 変更時）
xcodegen generate

# SPM 単体ビルド（Xcode なしでも可）
swift build
bash scripts/bundle.sh         # .app バンドル作成（コード署名なし）

# リリースビルド（DMG + 公証 + appcast 自動更新）
# 事前に notarytool のキーチェーンプロファイルを登録しておくこと
bash scripts/release.sh
```

`xcodebuild` を優先する。コード署名・Info.plist・Entitlements が自動処理される。

## Release Workflow

Sparkle 自動アップデート対応のため、以下の固定フローでリリースする。

```bash
# 1. バージョンを上げる（CFBundleShortVersionString と CFBundleVersion）
bash scripts/bump_version.sh 1.1            # build は現在値+1
bash scripts/bump_version.sh 1.1 5          # build を明示する場合

# 2. DMG ビルド・公証・appcast.xml 更新（一連で実行）
bash scripts/release.sh

# 3. GitHub Releases に DMG をアップロード
gh release create v1.1 build/release/ScreenshotApp.dmg --title "v1.1" --generate-notes

# 4. 更新済み appcast.xml と Info.plist を main に push
git add appcast.xml ScreenshotApp/Info.plist
git commit -m "release: v1.1"
git push
```

### release.sh の追加処理（手順 9）

DMG 作成・公証完了後に以下を自動実行する:

1. `Info.plist` から `CFBundleShortVersionString` と `CFBundleVersion` を読む
2. `.build/artifacts/sparkle/Sparkle/bin/sign_update --ed-key-file private-key-file <DMG>` で EdDSA 署名と length を取得
3. `appcast.xml` の `<channel>` に新 `<item>` を追記（同 `sparkle:version` の item があれば置換 — 冪等）
4. enclosure URL は `${DMG_URL_BASE}/v<short>/ScreenshotApp.dmg`（既定値: GitHub Releases）

### ローカル検証時の URL 上書き

GitHub Releases に上げる前に手元で挙動を確認したい場合、`DMG_URL_BASE` 環境変数で enclosure URL を差し替える:

```bash
DMG_URL_BASE="http://localhost:8000" bash scripts/release.sh
# 別ターミナルで feed と DMG を配信
cd build/release && python3 -m http.server 8000
# 旧版アプリを起動して feed URL を一時的に上書き
defaults write com.masakikubota.screenshot SUFeedURL "http://localhost:8000/appcast.xml"
# 検証完了後に元に戻す
defaults delete com.masakikubota.screenshot SUFeedURL
```

### 注意点

- **`private-key-file` は絶対に commit しない**（`.gitignore` 済み）。紛失すると全ユーザがアップデートを受けられなくなるため、1Password 等にバックアップ必須
- Sparkle は `CFBundleVersion`（数値）で新旧を判定する。表示用の `CFBundleShortVersionString` だけ上げてもアップデート対象にならないので、`bump_version.sh` で両方更新すること
- `appcast.xml` の `sparkle:edSignature` を手で編集してはいけない（署名検証が失敗する）。再生成が必要な場合は `release.sh` を再実行する

### 動作確認（プロセス停止 → 権限リセット → 再起動）

```bash
# 1. 実行中プロセスを停止
pkill -f ScreenshotApp

# 2. 画面収録の権限をリセット（再起動時に許可ダイアログが再表示される）
tccutil reset ScreenCapture com.masakikubota.screenshot

# 3. アプリを再起動
open ~/Library/Developer/Xcode/DerivedData/ScreenshotApp-*/Build/Products/Debug/ScreenshotApp.app
```

実装完了後は必ず上記 3 ステップすべてを実行すること。権限リセット（手順 2）により TCC データベースから許可が削除され、起動時に画面収録の許可ダイアログが再表示される。

## Distribution / Notarization Troubleshooting

`bash scripts/release.sh` が失敗した場合、以下の5要素を順に確認する。どの段階で詰まるかでログの出方が変わるため、エラーメッセージから該当項目に飛ぶこと。

| 段階 | 確認コマンド / 兆候 | 対処 |
|---|---|---|
| 1. Developer ID 証明書 | `security find-identity -v -p basic \| grep "Developer ID Application"` で `Masaki Kubota (L98U958G2N)` が出るか | 出なければ Xcode → Settings → Accounts → Manage Certificates から再発行、または `.p12` をインポート |
| 2. notarytool プロファイル | `xcrun notarytool history --keychain-profile "notarytool-profile"` で履歴が出るか | 「No Keychain password item found」なら `xcrun notarytool store-credentials "notarytool-profile" --apple-id <ID> --team-id L98U958G2N --password <App用パスワード>` |
| 3. PLA 同意状態 | `Error: HTTP status code: 403. A required agreement is missing or has expired.` | https://developer.apple.com/account の Agreements で更新版に再同意 |
| 4. Xcode コンポーネント | `IDESimulatorFoundation` の `Symbol not found` エラー | `sudo xcodebuild -runFirstLaunch` で追加コンポーネントを更新 |
| 5. Sparkle 内部署名 | `notarytool log` で `Sparkle.framework/Versions/B/...` が `not signed with a valid Developer ID certificate` 指摘 | `release.sh` の depth-first 再署名ステップ (3.5) が実行されているか確認。Sparkle のバージョン更新で内部構成が変わった場合は対象パスを更新 |

公証ステータスの読み方:
- `Accepted` → DMG は配布可能（`spctl -a -t open ...` で `accepted` / `source=Notarized Developer ID` を確認）
- `Invalid` → `release.sh` が自動で `notarytool log` を出力するので `issues` 配列を見る

Staple は配布の必須要件ではない（オフライン起動時の検証用）。失敗しても DMG は使える。後日 `xcrun stapler staple build/release/ScreenshotApp.dmg` 単独で再試行可能。

## Architecture

macOS メニューバー常駐のスクリーンショット注釈アプリ。SwiftUI + AppKit ハイブリッド構成。

### データフロー

```
MenuBarExtra (ScreenshotApp.swift)
  → ScreenshotManager: Process("/usr/sbin/screencapture -i -c") 実行
    → NSPasteboard から画像取得
      → ImageWindowController: NSWindow(level: .floating) を生成
        → NSHostingView で AnnotatedImageView (SwiftUI) を埋め込み
```

### MVVM パターン

- **Model**: `Annotation.swift` — enum `Annotation` + 5つの注釈データ型（Arrow, Rect, Text, Freehand, Mosaic）
- **ViewModel**: `CanvasViewModel` — ドラッグ/タップのステート管理、undo/clear
- **View**: `AnnotatedImageView` — ツールバー + Canvas + ジェスチャ + テキスト入力

### 描画の共有

`AnnotationRenderer`（静的メソッド）がライブキャンバスとエクスポート（`ExportManager` → `ImageRenderer`）の両方で描画ロジックを共有。モザイクは `CIPixellate` で事前計算した画像を `drawLayer` + `clip` で領域描画。

### 新しい注釈ツールを追加する手順

1. `Annotation.swift` — `AnnotationTool` に case 追加 + データ型定義
2. `CanvasViewModel.swift` — `handleDragStart` / `handleDragChanged` に分岐追加
3. `AnnotationRenderer.swift` — `draw()` の switch に描画処理追加
4. ツールバーは `AnnotationTool.allCases` で自動表示される

## Key Constraints

- **macOS 14.0+** ターゲット（Swift 5.9 language mode）
- **Swift 6 コンパイラ**（strict concurrency 有効）— `@MainActor` が必要な箇所あり（例: `ExportManager`）
- **App Sandbox 無効** — `screencapture` コマンド実行のため
- **LSUIElement = true** — Dock 非表示のメニューバー専用アプリ
- **外部依存なし** — AppKit, SwiftUI, CoreImage のみ使用
- **UI は日本語**

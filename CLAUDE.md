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
```

`xcodebuild` を優先する。コード署名・Info.plist・Entitlements が自動処理される。

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

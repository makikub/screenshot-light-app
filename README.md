# ScreenshotApp

macOS メニューバー常駐のスクリーンショット注釈アプリ。撮影した画像にその場で注釈を加えて保存・共有できる。

## Features

- メニューバーのカメラアイコンからワンクリックで範囲選択キャプチャ
- フローティングウィンドウで即座にプレビュー
- 5種類の注釈ツール:
  - 矢印 — 注目箇所を指し示す
  - 矩形 — 領域を囲って強調
  - テキスト — 説明文を配置
  - フリーハンド — 自由に描画
  - モザイク — 機密情報をピクセレートで隠す
- カラーピッカーで描画色を変更
- Undo / 全消去
- クリップボードにコピー（Cmd+Shift+C）
- PNG ファイルとして保存（Cmd+S）— オリジナル解像度で出力

## Requirements

- macOS 14.0+
- Swift 5.9+ / Swift 6 compiler
- Xcode Command Line Tools（`swift build` に必要）

## Build & Run

```bash
# .app バンドルをビルドして起動
bash scripts/bundle.sh
open .build/release/ScreenshotApp.app
```

開発時のデバッグビルド:

```bash
swift build
```

Xcode プロジェクトを生成する場合（要 [xcodegen](https://github.com/yonaskolb/XcodeGen)):

```bash
xcodegen generate
open ScreenshotApp.xcodeproj
```

## Architecture

SwiftUI + AppKit ハイブリッド構成の MVVM アーキテクチャ。

```
MenuBarExtra
  → ScreenshotManager (screencapture -i -c)
    → ImageWindowController (NSWindow, floating)
      → AnnotatedImageView (SwiftUI Canvas + Toolbar)
        ├── CanvasViewModel (state management)
        ├── AnnotationRenderer (shared drawing logic)
        └── ExportManager (clipboard / PNG export)
```

外部依存なし。AppKit, SwiftUI, CoreImage のみ使用。

## License

MIT

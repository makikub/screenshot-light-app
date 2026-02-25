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
- Xcode 16+（推奨）または Swift 5.9+ Command Line Tools
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`project.yml` から `.xcodeproj` を生成）

## Build & Run

### Xcode（推奨）

```bash
xcodegen generate              # .xcodeproj を生成
open ScreenshotApp.xcodeproj   # Xcode で開いて Cmd+R で実行
```

コマンドラインからビルド・起動する場合:

```bash
xcodebuild -project ScreenshotApp.xcodeproj -scheme ScreenshotApp -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/ScreenshotApp-*/Build/Products/Debug/ScreenshotApp.app
```

### Xcode なしの場合

```bash
bash scripts/bundle.sh
open .build/release/ScreenshotApp.app
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

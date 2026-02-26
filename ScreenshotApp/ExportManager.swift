import SwiftUI

/// 注釈付き画像のエクスポート（クリップボード・ファイル保存）
@MainActor
enum ExportManager {

    // MARK: - Render

    /// ImageRenderer を使って注釈付き画像をオリジナル解像度でレンダリングする
    static func render(image: NSImage, annotations: [Annotation], canvasSize: CGSize) -> NSImage? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }

        // モザイク注釈がある場合はピクセレート画像を生成
        let hasMosaic = annotations.contains { if case .mosaic = $0 { return true }; return false }
        let pixelated = hasMosaic ? ImagePixelator.pixelate(image) : nil

        let exportView = ExportableCanvasView(
            image: image,
            annotations: annotations,
            size: canvasSize,
            pixelatedImage: pixelated
        )

        let renderer = ImageRenderer(content: exportView)

        // オリジナル画像のピクセル解像度に合わせてスケール
        if let rep = image.representations.first, rep.pixelsWide > 0 {
            renderer.scale = CGFloat(rep.pixelsWide) / canvasSize.width
        } else {
            renderer.scale = image.size.width / canvasSize.width
        }

        return renderer.nsImage
    }

    // MARK: - Clipboard

    static func copyToClipboard(image: NSImage, annotations: [Annotation], canvasSize: CGSize) {
        // 注釈がなければオリジナル画像をそのままコピー
        let output: NSImage
        if annotations.isEmpty {
            output = image
        } else {
            guard let rendered = render(image: image, annotations: annotations, canvasSize: canvasSize)
            else { return }
            output = rendered
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([output])
    }

    // MARK: - Save to file

    static func saveToFile(image: NSImage, annotations: [Annotation], canvasSize: CGSize, parentWindow: NSWindow? = nil) {
        let output: NSImage
        if annotations.isEmpty {
            output = image
        } else {
            guard let rendered = render(image: image, annotations: annotations, canvasSize: canvasSize)
            else { return }
            output = rendered
        }

        guard let tiffData = output.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:])
        else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        panel.nameFieldStringValue = "screenshot_\(formatter.string(from: Date())).png"

        if let parentWindow {
            panel.beginSheetModal(for: parentWindow) { response in
                guard response == .OK, let url = panel.url else { return }
                try? pngData.write(to: url)
            }
        } else {
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                try? pngData.write(to: url)
            }
        }
    }
}

// MARK: - Export-only SwiftUI view

/// ImageRenderer 向けのビュー。AnnotationRenderer を再利用して描画する。
private struct ExportableCanvasView: View {
    let image: NSImage
    let annotations: [Annotation]
    let size: CGSize
    let pixelatedImage: NSImage?

    var body: some View {
        ZStack {
            Image(nsImage: image)
                .resizable()

            Canvas { context, canvasSize in
                AnnotationRenderer.draw(
                    annotations, in: &context,
                    size: canvasSize, pixelatedImage: pixelatedImage
                )
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

import SwiftUI

/// Canvas 描画とエクスポートの両方で使用する共通レンダラー
enum AnnotationRenderer {

    /// 注釈を描画する。モザイクがある場合は pixelatedImage を使用する。
    static func draw(
        _ annotations: [Annotation],
        in context: inout GraphicsContext,
        size: CGSize,
        pixelatedImage: NSImage? = nil
    ) {
        for annotation in annotations {
            switch annotation {
            case .arrow(let a):     drawArrow(a, in: &context)
            case .rectangle(let r): drawRect(r, in: &context)
            case .text(let t):      drawText(t, in: &context)
            case .freehand(let f):  drawFreehand(f, in: &context)
            case .mosaic(let m):
                if let pixelatedImage {
                    drawMosaic(m, in: &context, size: size, pixelatedImage: pixelatedImage)
                }
            }
        }
    }

    // MARK: - Arrow

    private static func drawArrow(_ a: ArrowAnnotation, in context: inout GraphicsContext) {
        let dx = a.end.x - a.start.x
        let dy = a.end.y - a.start.y
        let length = hypot(dx, dy)
        guard length > 1 else { return }

        // 単位ベクトル（方向 & 法線）
        let ux = dx / length
        let uy = dy / length
        let nx = -uy
        let ny = ux

        // テーパーパラメータ（lineWidth 基準）
        let tailWidth = a.lineWidth * 0.6
        let bodyEndWidth = a.lineWidth * 2.5
        let headLength = min(max(16, a.lineWidth * 6), length)
        let headWidth = max(20, a.lineWidth * 8)

        // 矢じり付け根の位置（end から headLength 分手前）
        let jx = a.end.x - ux * headLength
        let jy = a.end.y - uy * headLength

        // 始点側の2点（細い）
        let p1 = CGPoint(x: a.start.x + nx * tailWidth / 2,
                         y: a.start.y + ny * tailWidth / 2)
        let p2 = CGPoint(x: a.start.x - nx * tailWidth / 2,
                         y: a.start.y - ny * tailWidth / 2)

        // 矢じり付け根のボディ側2点（太い）
        let p3 = CGPoint(x: jx + nx * bodyEndWidth / 2,
                         y: jy + ny * bodyEndWidth / 2)
        let p4 = CGPoint(x: jx - nx * bodyEndWidth / 2,
                         y: jy - ny * bodyEndWidth / 2)

        // 矢じり翼の2点
        let p5 = CGPoint(x: jx + nx * headWidth / 2,
                         y: jy + ny * headWidth / 2)
        let p6 = CGPoint(x: jx - nx * headWidth / 2,
                         y: jy - ny * headWidth / 2)

        // ボディ + 矢じりを1つの連続パスで描画
        var path = Path()
        path.move(to: p1)
        path.addLine(to: p3)
        path.addLine(to: p5)
        path.addLine(to: a.end)
        path.addLine(to: p6)
        path.addLine(to: p4)
        path.addLine(to: p2)
        path.closeSubpath()

        context.fill(path, with: .color(a.color))
    }

    // MARK: - Rectangle

    private static func drawRect(_ r: RectAnnotation, in context: inout GraphicsContext) {
        let rect = CGRect(
            x: min(r.origin.x, r.origin.x + r.size.width),
            y: min(r.origin.y, r.origin.y + r.size.height),
            width: abs(r.size.width),
            height: abs(r.size.height)
        )
        context.stroke(Path(roundedRect: rect, cornerRadius: 2),
                       with: .color(r.color),
                       style: StrokeStyle(lineWidth: r.lineWidth))
    }

    // MARK: - Text

    private static func drawText(_ t: TextAnnotation, in context: inout GraphicsContext) {
        let resolved = context.resolve(
            Text(t.text)
                .font(.system(size: t.fontSize, weight: .bold))
                .foregroundColor(t.color)
        )
        context.draw(resolved, at: t.position, anchor: .topLeading)
    }

    // MARK: - Freehand

    private static func drawFreehand(_ f: FreehandAnnotation, in context: inout GraphicsContext) {
        guard f.points.count > 1 else { return }
        var path = Path()
        path.move(to: f.points[0])
        for point in f.points.dropFirst() {
            path.addLine(to: point)
        }
        context.stroke(path, with: .color(f.color),
                       style: StrokeStyle(lineWidth: f.lineWidth, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Mosaic

    /// モザイク領域にピクセレート画像をクリッピングして描画する
    private static func drawMosaic(
        _ m: MosaicAnnotation,
        in context: inout GraphicsContext,
        size: CGSize,
        pixelatedImage: NSImage
    ) {
        let rect = CGRect(
            x: min(m.origin.x, m.origin.x + m.size.width),
            y: min(m.origin.y, m.origin.y + m.size.height),
            width: abs(m.size.width),
            height: abs(m.size.height)
        )
        guard rect.width > 1, rect.height > 1 else { return }

        context.drawLayer { layerContext in
            layerContext.clip(to: Path(rect))
            layerContext.draw(
                Image(nsImage: pixelatedImage),
                in: CGRect(origin: .zero, size: size)
            )
        }
    }
}

// MARK: - Image pixelation

enum ImagePixelator {

    /// CIPixellate フィルタで画像全体をモザイク化した NSImage を返す
    static func pixelate(_ image: NSImage) -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData)
        else { return nil }

        // ブロックサイズを画像の大きさに応じて決定
        let maxDim = max(ciImage.extent.width, ciImage.extent.height)
        let blockSize = max(8, maxDim / 60)

        guard let filter = CIFilter(name: "CIPixellate") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(blockSize, forKey: kCIInputScaleKey)
        filter.setValue(CIVector(x: 0, y: 0), forKey: kCIInputCenterKey)

        guard let output = filter.outputImage else { return nil }

        // CIPixellate は境界を拡張することがあるため、元のサイズにクロップ
        let cropped = output.cropped(to: ciImage.extent)

        let rep = NSCIImageRep(ciImage: cropped)
        let result = NSImage(size: image.size)
        result.addRepresentation(rep)
        return result
    }
}

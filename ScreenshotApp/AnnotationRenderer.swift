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
        // Shaft
        var line = Path()
        line.move(to: a.start)
        line.addLine(to: a.end)
        context.stroke(line, with: .color(a.color),
                       style: StrokeStyle(lineWidth: a.lineWidth, lineCap: .round))

        // Arrowhead
        let angle = atan2(a.end.y - a.start.y, a.end.x - a.start.x)
        let headLength: CGFloat = max(12, a.lineWidth * 4)
        let headAngle: CGFloat = .pi / 6

        let p1 = CGPoint(
            x: a.end.x - headLength * cos(angle - headAngle),
            y: a.end.y - headLength * sin(angle - headAngle)
        )
        let p2 = CGPoint(
            x: a.end.x - headLength * cos(angle + headAngle),
            y: a.end.y - headLength * sin(angle + headAngle)
        )

        var head = Path()
        head.move(to: a.end)
        head.addLine(to: p1)
        head.addLine(to: p2)
        head.closeSubpath()
        context.fill(head, with: .color(a.color))
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

import SwiftUI

// MARK: - Tool

enum AnnotationTool: String, CaseIterable, Identifiable {
    case move
    case arrow
    case rectangle
    case text
    case freehand
    case mosaic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .move:      return "移動"
        case .arrow:     return "矢印"
        case .rectangle: return "矩形"
        case .text:      return "テキスト"
        case .freehand:  return "フリーハンド"
        case .mosaic:    return "モザイク"
        }
    }

    var iconName: String {
        switch self {
        case .move:      return "arrow.up.and.down.and.arrow.left.and.right"
        case .arrow:     return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .text:      return "textformat"
        case .freehand:  return "pencil.tip"
        case .mosaic:    return "square.grid.3x3"
        }
    }
}

// MARK: - Annotation types

enum Annotation: Identifiable {
    case arrow(ArrowAnnotation)
    case rectangle(RectAnnotation)
    case text(TextAnnotation)
    case freehand(FreehandAnnotation)
    case mosaic(MosaicAnnotation)

    var id: UUID {
        switch self {
        case .arrow(let a):     return a.id
        case .rectangle(let r): return r.id
        case .text(let t):      return t.id
        case .freehand(let f):  return f.id
        case .mosaic(let m):    return m.id
        }
    }
}

struct ArrowAnnotation {
    let id = UUID()
    var start: CGPoint
    var end: CGPoint
    var color: Color
    var lineWidth: CGFloat
}

struct RectAnnotation {
    let id = UUID()
    var origin: CGPoint
    var size: CGSize
    var color: Color
    var lineWidth: CGFloat
}

struct TextAnnotation {
    let id = UUID()
    var position: CGPoint
    var text: String
    var color: Color
    var fontSize: CGFloat
}

struct FreehandAnnotation {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
}

struct MosaicAnnotation {
    let id = UUID()
    var origin: CGPoint
    var size: CGSize
}

// MARK: - Annotation geometry

extension Annotation {
    var boundingRect: CGRect {
        switch self {
        case .arrow(let a):
            // start と end を包含する矩形 + padding
            let minX = min(a.start.x, a.end.x)
            let minY = min(a.start.y, a.end.y)
            let maxX = max(a.start.x, a.end.x)
            let maxY = max(a.start.y, a.end.y)
            let padding = max(a.lineWidth * 4, 10) // 矢じり分のパディング
            return CGRect(x: minX - padding, y: minY - padding,
                          width: maxX - minX + padding * 2, height: maxY - minY + padding * 2)
        case .rectangle(let r):
            return CGRect(
                x: min(r.origin.x, r.origin.x + r.size.width),
                y: min(r.origin.y, r.origin.y + r.size.height),
                width: abs(r.size.width), height: abs(r.size.height)
            ).insetBy(dx: -r.lineWidth, dy: -r.lineWidth)
        case .text(let t):
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: t.fontSize, weight: .bold)
            ]
            let size = (t.text as NSString).size(withAttributes: attrs)
            return CGRect(origin: t.position, size: size)
        case .freehand(let f):
            guard let first = f.points.first else { return .zero }
            var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
            for p in f.points {
                minX = min(minX, p.x); minY = min(minY, p.y)
                maxX = max(maxX, p.x); maxY = max(maxY, p.y)
            }
            let padding = f.lineWidth / 2
            return CGRect(x: minX - padding, y: minY - padding,
                          width: maxX - minX + padding * 2, height: maxY - minY + padding * 2)
        case .mosaic(let m):
            return CGRect(
                x: min(m.origin.x, m.origin.x + m.size.width),
                y: min(m.origin.y, m.origin.y + m.size.height),
                width: abs(m.size.width), height: abs(m.size.height)
            )
        }
    }

    func translated(by offset: CGSize) -> Annotation {
        switch self {
        case .arrow(var a):
            a.start.x += offset.width;  a.start.y += offset.height
            a.end.x += offset.width;    a.end.y += offset.height
            return .arrow(a)
        case .rectangle(var r):
            r.origin.x += offset.width; r.origin.y += offset.height
            return .rectangle(r)
        case .text(var t):
            t.position.x += offset.width; t.position.y += offset.height
            return .text(t)
        case .freehand(var f):
            f.points = f.points.map { CGPoint(x: $0.x + offset.width, y: $0.y + offset.height) }
            return .freehand(f)
        case .mosaic(var m):
            m.origin.x += offset.width; m.origin.y += offset.height
            return .mosaic(m)
        }
    }
}

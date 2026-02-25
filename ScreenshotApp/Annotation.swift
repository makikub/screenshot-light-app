import SwiftUI

// MARK: - Tool

enum AnnotationTool: String, CaseIterable, Identifiable {
    case arrow
    case rectangle
    case text
    case freehand
    case mosaic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .arrow:     return "矢印"
        case .rectangle: return "矩形"
        case .text:      return "テキスト"
        case .freehand:  return "フリーハンド"
        case .mosaic:    return "モザイク"
        }
    }

    var iconName: String {
        switch self {
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

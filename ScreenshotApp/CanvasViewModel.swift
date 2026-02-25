import SwiftUI

final class CanvasViewModel: ObservableObject {
    @Published var currentTool: AnnotationTool = .arrow
    @Published var annotations: [Annotation] = []
    @Published var currentAnnotation: Annotation?
    @Published var strokeColor: Color = .red
    @Published var lineWidth: CGFloat = 3
    @Published var fontSize: CGFloat = 20

    // Text editing state
    @Published var isEditingText = false
    @Published var editingTextPosition: CGPoint = .zero
    @Published var editingText: String = ""

    // MARK: - Drag handling

    func handleDragStart(at point: CGPoint) {
        guard currentTool != .text else { return }
        switch currentTool {
        case .arrow:
            currentAnnotation = .arrow(ArrowAnnotation(
                start: point, end: point,
                color: strokeColor, lineWidth: lineWidth
            ))
        case .rectangle:
            currentAnnotation = .rectangle(RectAnnotation(
                origin: point, size: .zero,
                color: strokeColor, lineWidth: lineWidth
            ))
        case .freehand:
            currentAnnotation = .freehand(FreehandAnnotation(
                points: [point],
                color: strokeColor, lineWidth: lineWidth
            ))
        case .mosaic:
            currentAnnotation = .mosaic(MosaicAnnotation(
                origin: point, size: .zero
            ))
        case .text:
            break
        }
    }

    func handleDragChanged(to point: CGPoint) {
        switch currentAnnotation {
        case .arrow(var a):
            a.end = point
            currentAnnotation = .arrow(a)
        case .rectangle(var r):
            r.size = CGSize(width: point.x - r.origin.x, height: point.y - r.origin.y)
            currentAnnotation = .rectangle(r)
        case .freehand(var f):
            f.points.append(point)
            currentAnnotation = .freehand(f)
        case .mosaic(var m):
            m.size = CGSize(width: point.x - m.origin.x, height: point.y - m.origin.y)
            currentAnnotation = .mosaic(m)
        default:
            break
        }
    }

    func handleDragEnd(at point: CGPoint) {
        handleDragChanged(to: point)
        if let annotation = currentAnnotation {
            annotations.append(annotation)
            currentAnnotation = nil
        }
    }

    // MARK: - Text

    func handleTap(at point: CGPoint) {
        guard currentTool == .text else { return }
        if isEditingText { commitText() }
        isEditingText = true
        editingTextPosition = point
        editingText = ""
    }

    func commitText() {
        if !editingText.isEmpty {
            annotations.append(.text(TextAnnotation(
                position: editingTextPosition,
                text: editingText,
                color: strokeColor,
                fontSize: fontSize
            )))
        }
        isEditingText = false
        editingText = ""
    }

    // MARK: - Edit operations

    func undo() {
        guard !annotations.isEmpty else { return }
        annotations.removeLast()
    }

    func clear() {
        annotations.removeAll()
        currentAnnotation = nil
        isEditingText = false
        editingText = ""
    }
}

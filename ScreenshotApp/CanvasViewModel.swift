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

    // Move state
    @Published var movingAnnotationIndex: Int? = nil
    var originalAnnotation: Annotation?
    var dragStartPoint: CGPoint = .zero

    // Undo history
    var history: [[Annotation]] = []

    var isDragActive: Bool {
        currentAnnotation != nil || movingAnnotationIndex != nil
    }

    private func pushHistory() {
        history.append(annotations)
    }

    // MARK: - Drag handling

    func handleDragStart(at point: CGPoint) {
        guard currentTool != .text else { return }
        switch currentTool {
        case .move:
            if let index = AnnotationRenderer.hitTest(point: point, in: annotations) {
                pushHistory()
                movingAnnotationIndex = index
                originalAnnotation = annotations[index]
                dragStartPoint = point
            }
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
        if currentTool == .move {
            guard let index = movingAnnotationIndex, let original = originalAnnotation else { return }
            let offset = CGSize(width: point.x - dragStartPoint.x, height: point.y - dragStartPoint.y)
            annotations[index] = original.translated(by: offset)
            return
        }

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
        if currentTool == .move {
            // 移動の最終位置を適用してクリア
            handleDragChanged(to: point)
            movingAnnotationIndex = nil
            originalAnnotation = nil
            return
        }

        handleDragChanged(to: point)
        if let annotation = currentAnnotation {
            pushHistory()
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
            pushHistory()
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
        guard let previous = history.popLast() else { return }
        annotations = previous
        currentAnnotation = nil
        movingAnnotationIndex = nil
        originalAnnotation = nil
    }

    func clear() {
        guard !annotations.isEmpty else { return }
        pushHistory()
        annotations.removeAll()
        currentAnnotation = nil
        movingAnnotationIndex = nil
        originalAnnotation = nil
        isEditingText = false
        editingText = ""
    }
}

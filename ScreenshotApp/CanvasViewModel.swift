import SwiftUI

final class CanvasViewModel: ObservableObject {
    @Published var currentTool: AnnotationTool = .arrow
    @Published var annotations: [Annotation] = []
    @Published var currentAnnotation: Annotation?
    @Published var strokeColor: Color = .red {
        didSet { Self.saveColor(strokeColor) }
    }
    @Published var lineWidth: CGFloat = 3 {
        didSet { UserDefaults.standard.set(Double(lineWidth), forKey: "lineWidth") }
    }
    @Published var fontSize: CGFloat = 20 {
        didSet { UserDefaults.standard.set(Double(fontSize), forKey: "fontSize") }
    }

    // Text editing state
    @Published var isEditingText = false
    @Published var editingTextPosition: CGPoint = .zero
    @Published var editingText: String = ""

    // Move state
    @Published var movingAnnotationIndex: Int? = nil
    var originalAnnotation: Annotation?
    var dragStartPoint: CGPoint = .zero

    // Crop state
    @Published var cropSelection: CGRect?
    var isDrawingCropSelection = false

    // Undo history
    var history: [[Annotation]] = []

    init() {
        let defaults = UserDefaults.standard
        if let color = Self.loadColor() {
            strokeColor = color
        }
        if defaults.object(forKey: "lineWidth") != nil {
            lineWidth = CGFloat(defaults.double(forKey: "lineWidth"))
        }
        if defaults.object(forKey: "fontSize") != nil {
            fontSize = CGFloat(defaults.double(forKey: "fontSize"))
        }
    }

    // MARK: - Color persistence

    private static func saveColor(_ color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        UserDefaults.standard.set(Double(nsColor.redComponent), forKey: "strokeColorR")
        UserDefaults.standard.set(Double(nsColor.greenComponent), forKey: "strokeColorG")
        UserDefaults.standard.set(Double(nsColor.blueComponent), forKey: "strokeColorB")
        UserDefaults.standard.set(Double(nsColor.alphaComponent), forKey: "strokeColorA")
    }

    private static func loadColor() -> Color? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "strokeColorR") != nil else { return nil }
        let r = defaults.double(forKey: "strokeColorR")
        let g = defaults.double(forKey: "strokeColorG")
        let b = defaults.double(forKey: "strokeColorB")
        let a = defaults.double(forKey: "strokeColorA")
        return Color(red: r, green: g, blue: b, opacity: a)
    }

    var isDragActive: Bool {
        currentAnnotation != nil || movingAnnotationIndex != nil || isDrawingCropSelection
    }

    var canApplyCrop: Bool {
        guard let cropSelection else { return false }
        return annotations.isEmpty && cropSelection.width >= 4 && cropSelection.height >= 4
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
        case .crop:
            dragStartPoint = point
            isDrawingCropSelection = true
            cropSelection = CGRect(origin: point, size: .zero)
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

        if currentTool == .crop {
            guard isDrawingCropSelection else { return }
            cropSelection = Self.normalizedRect(from: dragStartPoint, to: point)
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

        if currentTool == .crop {
            handleDragChanged(to: point)
            isDrawingCropSelection = false
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
        cropSelection = nil
        isDrawingCropSelection = false
    }

    func clear() {
        guard !annotations.isEmpty else { return }
        pushHistory()
        annotations.removeAll()
        currentAnnotation = nil
        movingAnnotationIndex = nil
        originalAnnotation = nil
        cropSelection = nil
        isDrawingCropSelection = false
        isEditingText = false
        editingText = ""
    }

    func cancelCrop() {
        cropSelection = nil
        isDrawingCropSelection = false
    }

    func finishCrop() {
        cropSelection = nil
        currentTool = .arrow
    }

    private static func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }
}

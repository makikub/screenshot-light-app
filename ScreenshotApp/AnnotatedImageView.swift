import SwiftUI

struct AnnotatedImageView: View {
    @State private var image: NSImage
    @StateObject private var viewModel = CanvasViewModel()
    @State private var canvasSize: CGSize = .zero
    @State private var pixelatedImages: [Int: NSImage] = [:]
    @FocusState private var isTextFieldFocused: Bool

    init(image: NSImage) {
        _image = State(initialValue: image)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbarSection
            canvasSection
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    // MARK: - Toolbar

    private var toolbarSection: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    glassGroup(spacing: 2) {
                        ForEach(AnnotationTool.allCases) { tool in
                            Button {
                                if viewModel.isEditingText { viewModel.commitText() }
                                viewModel.currentTool = tool
                            } label: {
                                Image(systemName: tool.iconName)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .buttonStyle(GlassToolbarButtonStyle(isSelected: viewModel.currentTool == tool))
                            .help(tool.label)
                        }
                    }

                    glassDivider

                    glassGroup(spacing: 8) {
                        if viewModel.currentTool == .mosaic {
                            mosaicBlockSizeControl
                        } else {
                            ColorPicker("", selection: $viewModel.strokeColor)
                                .labelsHidden()
                                .frame(width: 28, height: 28)
                                .help("注釈の色")

                            if showsLineWidthControl {
                                lineWidthControl
                            }

                            if viewModel.currentTool == .rectangle {
                                rectStyleControl
                            }
                        }
                    }

                    glassDivider

                    glassGroup(spacing: 2) {
                        Button { viewModel.undo() } label: {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .buttonStyle(GlassToolbarButtonStyle())
                        .disabled(viewModel.history.isEmpty)
                        .help("取り消し")
                        .keyboardShortcut("z", modifiers: .command)

                        Button { viewModel.clear() } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(GlassToolbarButtonStyle(role: .destructive))
                        .disabled(viewModel.annotations.isEmpty)
                        .help("全消去")
                    }

                    if viewModel.currentTool == .crop {
                        glassDivider

                        glassGroup(spacing: 4) {
                            Button { applyCrop() } label: {
                                Image(systemName: "checkmark")
                            }
                            .buttonStyle(GlassToolbarButtonStyle(isSelected: viewModel.canApplyCrop))
                            .disabled(!viewModel.canApplyCrop)
                            .help("選択範囲で画像をクロップ")

                            Button { viewModel.cancelCrop() } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(GlassToolbarButtonStyle())
                            .disabled(viewModel.cropSelection == nil)
                            .help("クロップ選択をキャンセル")
                        }
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }

            glassGroup(spacing: 4) {
                Button { copyToClipboard() } label: {
                    Label("コピー", systemImage: "doc.on.doc")
                }
                .buttonStyle(GlassProminentButtonStyle())
                .help("クリップボードにコピー")
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button { saveToFile() } label: {
                    Label("保存", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(GlassProminentButtonStyle())
                .help("ファイルに保存")
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.white.opacity(0.18))
                        .frame(height: 1)
                }
        }
    }

    // MARK: - Canvas section

    private var canvasSection: some View {
        GeometryReader { geometry in
            let displaySize = imageDisplaySize(in: geometry.size)

            ZStack(alignment: .topLeading) {
                Image(nsImage: image)
                    .resizable()

                Canvas { context, size in
                    var allAnnotations = viewModel.annotations
                    if let current = viewModel.currentAnnotation {
                        allAnnotations.append(current)
                    }
                    AnnotationRenderer.draw(
                        allAnnotations, in: &context,
                        size: size, pixelatedImages: pixelatedImages,
                        selectedAnnotationId: viewModel.movingAnnotationIndex.map { viewModel.annotations[$0].id }
                    )
                }

                if viewModel.isEditingText {
                    textEditingOverlay
                }

                if let cropSelection = viewModel.cropSelection {
                    cropSelectionOverlay(cropSelection, in: displaySize)
                }
            }
            .frame(width: displaySize.width, height: displaySize.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(canvasGesture)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: displaySize) { _, newSize in
                canvasSize = newSize
            }
            .onAppear {
                canvasSize = displaySize
                refreshPixelatedImages()
            }
            .onChange(of: image) { _, newImage in
                refreshPixelatedImages(for: newImage)
            }
            .onChange(of: viewModel.mosaicBlockSize) {
                refreshPixelatedImages()
            }
            .onChange(of: viewModel.annotations.map(\.id)) {
                refreshPixelatedImages()
            }
            .onChange(of: viewModel.currentAnnotation?.id) {
                refreshPixelatedImages()
            }
            .onChange(of: viewModel.isEditingText) { _, isEditingText in
                if isEditingText {
                    focusTextField()
                } else {
                    isTextFieldFocused = false
                }
            }
            .onKeyPress(characters: .init(charactersIn: "1234567")) { press in
                guard !viewModel.isEditingText else { return .ignored }
                let tools = AnnotationTool.allCases
                if let index = Int(String(press.characters.first ?? "0")),
                   index >= 1, index <= tools.count {
                    if viewModel.isEditingText { viewModel.commitText() }
                    viewModel.currentTool = tools[index - 1]
                    return .handled
                }
                return .ignored
            }
        }
    }

    private var mosaicBlockSizeControl: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.grid.3x3")
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
            Slider(value: $viewModel.mosaicBlockSize, in: 2...32, step: 1)
                .frame(width: 110)
                .help("モザイクの荒さ")
            Text("\(Int(viewModel.mosaicBlockSize))")
                .monospacedDigit()
                .frame(width: 24, alignment: .trailing)
        }
        .help("モザイクの荒さ")
    }

    private var showsLineWidthControl: Bool {
        switch viewModel.currentTool {
        case .arrow, .rectangle, .freehand:
            return true
        case .move, .crop, .text, .mosaic:
            return false
        }
    }

    private var lineWidthControl: some View {
        HStack(spacing: 6) {
            Image(systemName: "lineweight")
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
            Slider(value: $viewModel.lineWidth, in: 1...16, step: 1)
                .frame(width: 90)
                .help("線の太さ")
            Text("\(Int(viewModel.lineWidth))")
                .monospacedDigit()
                .frame(width: 18, alignment: .trailing)
        }
        .help("線の太さ")
    }

    private var rectStyleControl: some View {
        Menu {
            ForEach(RectStyle.allCases) { style in
                Button {
                    viewModel.rectStyle = style
                } label: {
                    Label(style.label, systemImage: style.iconName)
                }
            }
        } label: {
            Image(systemName: viewModel.rectStyle.iconName)
                .frame(width: 24, height: 24)
        }
        .menuStyle(.button)
        .buttonStyle(GlassToolbarButtonStyle())
        .help("矩形スタイル: \(viewModel.rectStyle.label)")
    }

    private var glassDivider: some View {
        Capsule()
            .fill(.primary.opacity(0.16))
            .frame(width: 1, height: 26)
            .padding(.horizontal, 1)
    }

    private func glassGroup<Content: View>(
        spacing: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: spacing) {
            content()
        }
        .padding(4)
        .frame(height: 38)
        .liquidGlass(in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 5)
    }

    private func refreshPixelatedImages(for sourceImage: NSImage? = nil) {
        let sourceImage = sourceImage ?? image
        let blockSizes = Set(mosaicBlockSizes(in: viewModel.annotations + [viewModel.currentAnnotation].compactMap { $0 }))
        pixelatedImages = blockSizes.reduce(into: [:]) { images, blockSize in
            images[blockSize] = ImagePixelator.pixelate(sourceImage, blockSize: CGFloat(blockSize))
        }
    }

    private func mosaicBlockSizes(in annotations: [Annotation]) -> [Int] {
        var sizes = annotations.compactMap { annotation -> Int? in
            guard case .mosaic(let mosaic) = annotation else { return nil }
            return Int(mosaic.blockSize.rounded())
        }
        sizes.append(Int(viewModel.mosaicBlockSize.rounded()))
        return sizes
    }

    /// 利用可能な領域内で画像のアスペクト比を維持したサイズを計算
    private func imageDisplaySize(in available: CGSize) -> CGSize {
        guard image.size.width > 0, image.size.height > 0 else { return available }
        let imageAspect = image.size.width / image.size.height
        let viewAspect = available.width / available.height

        if imageAspect > viewAspect {
            return CGSize(width: available.width, height: available.width / imageAspect)
        } else {
            return CGSize(width: available.height * imageAspect, height: available.height)
        }
    }

    // MARK: - Gesture

    private var canvasGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if viewModel.currentTool == .text { return }
                if !viewModel.isDragActive {
                    viewModel.handleDragStart(at: value.startLocation)
                }
                viewModel.handleDragChanged(to: value.location)
            }
            .onEnded { value in
                let distance = hypot(
                    value.location.x - value.startLocation.x,
                    value.location.y - value.startLocation.y
                )
                if viewModel.currentTool == .text {
                    if distance < 5 {
                        viewModel.handleTap(at: value.startLocation)
                    }
                } else {
                    viewModel.handleDragEnd(at: value.location)
                }
            }
    }

    // MARK: - Text editing overlay

    private var textEditingOverlay: some View {
        TextField("テキストを入力（Enterで確定）", text: $viewModel.editingText)
            .textFieldStyle(.plain)
            .focused($isTextFieldFocused)
            .font(.system(size: viewModel.fontSize, weight: .bold))
            .foregroundStyle(viewModel.strokeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
            .fixedSize()
            .offset(
                x: viewModel.editingTextPosition.x,
                y: viewModel.editingTextPosition.y
            )
            .onAppear {
                focusTextField()
            }
            .onSubmit {
                viewModel.commitText()
            }
    }

    private func focusTextField() {
        DispatchQueue.main.async {
            isTextFieldFocused = true
        }
    }

    // MARK: - Crop

    private func cropSelectionOverlay(_ selection: CGRect, in displaySize: CGSize) -> some View {
        let rect = selection.intersection(CGRect(origin: .zero, size: displaySize))

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(.black.opacity(0.35))
                .mask {
                    Rectangle()
                        .overlay(alignment: .topLeading) {
                            Rectangle()
                                .frame(width: rect.width, height: rect.height)
                                .offset(x: rect.minX, y: rect.minY)
                                .blendMode(.destinationOut)
                        }
                }

            Rectangle()
                .stroke(.white, style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }

    private func applyCrop() {
        if viewModel.isEditingText { viewModel.commitText() }

        guard viewModel.canApplyCrop,
              let selection = viewModel.cropSelection
        else { return }

        let shouldBakeAnnotations = !viewModel.annotations.isEmpty
        let sourceImage: NSImage
        if shouldBakeAnnotations {
            guard let rendered = ExportManager.render(
                image: image,
                annotations: viewModel.annotations,
                canvasSize: canvasSize
            ) else { return }
            sourceImage = rendered
        } else {
            sourceImage = image
        }

        guard let cropped = ImageCropper.crop(sourceImage, to: selection, displayedIn: canvasSize)
        else { return }

        image = cropped
        viewModel.finishCrop(clearingAnnotations: shouldBakeAnnotations)
    }

    // MARK: - Export (Phase 3)

    private func copyToClipboard() {
        if viewModel.isEditingText { viewModel.commitText() }
        ExportManager.copyToClipboard(
            image: image,
            annotations: viewModel.annotations,
            canvasSize: canvasSize
        )
    }

    private func saveToFile() {
        if viewModel.isEditingText { viewModel.commitText() }
        ExportManager.saveToFile(
            image: image,
            annotations: viewModel.annotations,
            canvasSize: canvasSize,
            parentWindow: NSApp.keyWindow
        )
    }
}

private struct GlassToolbarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    enum Role {
        case standard
        case destructive
    }

    var isSelected = false
    var role: Role = .standard

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .opacity(isEnabled ? 1 : 0.38)
            .frame(width: 30, height: 30)
            .background {
                Capsule()
                    .fill(backgroundStyle(isPressed: configuration.isPressed))
            }
            .overlay {
                Capsule()
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1.2 : 0.8)
            }
            .shadow(
                color: isSelected ? Color.accentColor.opacity(0.22) : .clear,
                radius: 7,
                x: 0,
                y: 3
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.16), value: isSelected)
    }

    private var foregroundColor: Color {
        guard isEnabled else { return .secondary }

        if role == .destructive {
            return isSelected ? .white : .red
        }
        return isSelected ? .white : .primary
    }

    private var borderColor: Color {
        isSelected ? .white.opacity(0.42) : .white.opacity(0.16)
    }

    private func backgroundStyle(isPressed: Bool) -> AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(isPressed ? 0.92 : 0.78))
        }

        if isPressed {
            return AnyShapeStyle(Color.primary.opacity(0.14))
        }

        return AnyShapeStyle(Color.white.opacity(0.001))
    }
}

private struct GlassProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .opacity(isEnabled ? 1 : 0.4)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background {
                Capsule()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.07))
            }
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 7, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private extension View {
    func liquidGlass<S: InsettableShape>(in shape: S) -> some View {
        glassEffect(.regular, in: shape)
    }
}

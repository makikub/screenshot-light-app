import SwiftUI

struct AnnotatedImageView: View {
    let image: NSImage
    @StateObject private var viewModel = CanvasViewModel()
    @State private var canvasSize: CGSize = .zero
    @State private var pixelatedImage: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            toolbarSection
            canvasSection
        }
    }

    // MARK: - Toolbar

    private var toolbarSection: some View {
        HStack(spacing: 8) {
            ForEach(AnnotationTool.allCases) { tool in
                Button {
                    if viewModel.isEditingText { viewModel.commitText() }
                    viewModel.currentTool = tool
                } label: {
                    Image(systemName: tool.iconName)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.currentTool == tool ? .accentColor : nil)
                .help(tool.label)
            }

            Divider().frame(height: 20)

            ColorPicker("", selection: $viewModel.strokeColor)
                .labelsHidden()
                .frame(width: 30)

            Divider().frame(height: 20)

            Button { viewModel.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(viewModel.history.isEmpty)
            .help("取り消し")
            .keyboardShortcut("z", modifiers: .command)

            Button { viewModel.clear() } label: {
                Image(systemName: "trash")
            }
            .disabled(viewModel.annotations.isEmpty)
            .help("全消去")

            Spacer()

            Button { copyToClipboard() } label: {
                Label("コピー", systemImage: "doc.on.doc")
            }
            .help("クリップボードにコピー")
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button { saveToFile() } label: {
                Label("保存", systemImage: "square.and.arrow.down")
            }
            .help("ファイルに保存")
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Canvas section

    private var canvasSection: some View {
        GeometryReader { geometry in
            let displaySize = imageDisplaySize(in: geometry.size)

            ZStack {
                Image(nsImage: image)
                    .resizable()

                Canvas { context, size in
                    var allAnnotations = viewModel.annotations
                    if let current = viewModel.currentAnnotation {
                        allAnnotations.append(current)
                    }
                    AnnotationRenderer.draw(
                        allAnnotations, in: &context,
                        size: size, pixelatedImage: pixelatedImage,
                        selectedAnnotationId: viewModel.movingAnnotationIndex.map { viewModel.annotations[$0].id }
                    )
                }

                if viewModel.isEditingText {
                    textEditingOverlay
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
                pixelatedImage = ImagePixelator.pixelate(image)
            }
        }
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
        TextField("テキストを入力", text: $viewModel.editingText)
            .textFieldStyle(.plain)
            .font(.system(size: viewModel.fontSize, weight: .bold))
            .foregroundStyle(viewModel.strokeColor)
            .padding(4)
            .background(Color.white.opacity(0.8))
            .cornerRadius(4)
            .fixedSize()
            .position(viewModel.editingTextPosition)
            .onSubmit {
                viewModel.commitText()
            }
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

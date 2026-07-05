import AppKit

final class ScreenshotManager: ObservableObject {
    private var windowControllers: [ImageWindowController] = []
    private var thumbnailPanel: ThumbnailPanel?

    /// `screencapture -i -c` を実行し、撮影後にクリップボードから画像を取得して表示する
    func captureScreenshot() {
        // 既存のサムネイルを即座に閉じる
        thumbnailPanel?.orderOut(nil)
        thumbnailPanel = nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-c"]

        process.terminationHandler = { [weak self] terminatedProcess in
            guard terminatedProcess.terminationStatus == 0 else { return }
            DispatchQueue.main.async {
                self?.showCapturedImage()
            }
        }

        do {
            try process.run()
        } catch {
            print("screencapture の起動に失敗: \(error)")
        }
    }

    private func showCapturedImage() {
        guard let image = NSImage(pasteboard: NSPasteboard.general) else {
            return
        }

        let panel = ThumbnailPanel(
            image: image,
            onOpen: { [weak self] in
                self?.thumbnailPanel = nil
                self?.openEditor(with: image)
            },
            onDismiss: { [weak self] in
                self?.thumbnailPanel = nil
            }
        )
        thumbnailPanel = panel
    }

    private func openEditor(with image: NSImage) {
        let controller = ImageWindowController(image: image)
        controller.onClose = { [weak self, weak controller] in
            guard let controller else { return }
            self?.removeWindowController(controller)
        }
        controller.showWindow(nil)
        controller.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        windowControllers.append(controller)
    }

    func closeAllScreenshots() {
        thumbnailPanel?.close()
        thumbnailPanel = nil

        let controllers = windowControllers
        windowControllers.removeAll()
        controllers.forEach { $0.close() }
    }

    #if DEBUG
    func showDebugSampleEditor() {
        openEditor(with: Self.makeDebugSampleImage())
    }

    private static func makeDebugSampleImage() -> NSImage {
        let size = NSSize(width: 960, height: 560)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        let bounds = NSRect(origin: .zero, size: size)
        NSGradient(colors: [
            NSColor(calibratedRed: 0.08, green: 0.14, blue: 0.24, alpha: 1),
            NSColor(calibratedRed: 0.20, green: 0.34, blue: 0.54, alpha: 1),
            NSColor(calibratedRed: 0.91, green: 0.74, blue: 0.42, alpha: 1)
        ])?.draw(in: bounds, angle: 18)

        NSColor.white.withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: NSRect(x: 64, y: 72, width: 340, height: 180), xRadius: 24, yRadius: 24).fill()
        NSBezierPath(roundedRect: NSRect(x: 536, y: 278, width: 300, height: 170), xRadius: 24, yRadius: 24).fill()

        NSColor.systemTeal.withAlphaComponent(0.75).setFill()
        NSBezierPath(ovalIn: NSRect(x: 120, y: 304, width: 160, height: 160)).fill()

        NSColor.systemPink.withAlphaComponent(0.68).setFill()
        NSBezierPath(ovalIn: NSRect(x: 292, y: 326, width: 220, height: 120)).fill()

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 48, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        "Liquid Glass Preview".draw(at: NSPoint(x: 64, y: 458), withAttributes: titleAttributes)

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.82)
        ]
        "明暗と色の変化がある背景で、ツールバーの透明感と可読性を確認するためのDebug用サンプルです。"
            .draw(in: NSRect(x: 64, y: 398, width: 780, height: 64), withAttributes: bodyAttributes)

        return image
    }
    #endif

    private func removeWindowController(_ controller: ImageWindowController) {
        windowControllers.removeAll { $0 === controller }
    }
}

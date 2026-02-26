import AppKit

final class ScreenshotManager: ObservableObject {
    private var windowController: ImageWindowController?
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
        controller.showWindow(nil)
        controller.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        windowController = controller
    }
}

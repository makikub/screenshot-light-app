import AppKit

final class ScreenshotManager: ObservableObject {
    private var windowController: ImageWindowController?

    /// `screencapture -i -c` を実行し、撮影後にクリップボードから画像を取得して表示する
    func captureScreenshot() {
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

        let controller = ImageWindowController(image: image)
        controller.showWindow(nil)
        // ウィンドウを最前面にしてフォーカスする
        controller.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        windowController = controller
    }
}

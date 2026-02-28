import AppKit
import SwiftUI

final class ImageWindowController: NSWindowController, NSWindowDelegate {

    convenience init(image: NSImage) {
        let toolbarHeight: CGFloat = 44
        let imageSize = Self.calcImageSize(for: image)
        let windowSize = NSSize(width: imageSize.width, height: imageSize.height + toolbarHeight)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.level = .normal
        window.title = "Screenshot"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 400, height: 300)
        window.contentView = NSHostingView(rootView: AnnotatedImageView(image: image))
        window.center()

        self.init(window: window)
        window.delegate = self
    }

    // MARK: - Window size calculation

    /// 画像サイズを画面の90%以内に収まるよう計算する
    private static func calcImageSize(for image: NSImage) -> NSSize {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame
        let maxWidth = visibleFrame.width * 0.9
        let maxHeight = visibleFrame.height * 0.85 // ツールバー分を考慮

        let backingScale = screen.backingScaleFactor
        let pointSize: NSSize
        if let rep = image.representations.first, rep.pixelsWide > 0 {
            pointSize = NSSize(
                width: CGFloat(rep.pixelsWide) / backingScale,
                height: CGFloat(rep.pixelsHigh) / backingScale
            )
        } else {
            pointSize = image.size
        }

        let scale = min(1.0, min(maxWidth / pointSize.width, maxHeight / pointSize.height))
        return NSSize(
            width: ceil(pointSize.width * scale),
            height: ceil(pointSize.height * scale)
        )
    }
}

import AppKit
import SwiftUI

/// スクリーンショット撮影後に画面左下に表示するサムネイルプレビュー。
/// クリックで注釈エディタへ遷移する。閉じるボタンで明示的に消す。
final class ThumbnailPanel: NSPanel {
    private var onOpenEditor: (() -> Void)?
    private var onDismissed: (() -> Void)?

    convenience init(image: NSImage, onOpen: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        // 正方形サムネイル（200×200 pt）
        let thumbSide: CGFloat = 200
        let inset: CGFloat = 12 // shadow 用の余白
        let panelSize = NSSize(width: thumbSide + inset * 2,
                               height: thumbSide + inset * 2)

        self.init(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.onOpenEditor = onOpen
        self.onDismissed = onDismiss

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false // SwiftUI 側で shadow を描画
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true

        let hostingView = NSHostingView(rootView: ThumbnailContentView(
            image: image,
            onOpen: { [weak self] in self?.openEditor() },
            onClose: { [weak self] in self?.animateDismiss() }
        ))
        contentView = hostingView

        positionAtBottomLeft()
        alphaValue = 0
        orderFrontRegardless()
        DispatchQueue.main.async { [weak self] in
            self?.animateIn()
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Position & Animation

    private func positionAtBottomLeft() {
        guard let screen = NSScreen.main else { return }
        // X: visibleFrame を使い左 Dock を避ける
        // Y: screen.frame ベースで Dock の表示/非表示に左右されない固定位置
        let xMargin: CGFloat = 48
        let yOffset: CGFloat = 96 // Dock（最大約80pt）を常に超える固定オフセット
        setFrameOrigin(NSPoint(
            x: screen.visibleFrame.origin.x + xMargin,
            y: screen.frame.origin.y + yOffset
        ))
    }

    private func animateIn() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
    }

    private func animateDismiss() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.onDismissed?()
            self?.close()
        })
    }

    // MARK: - Actions

    private func openEditor() {
        let callback = onOpenEditor
        onOpenEditor = nil
        onDismissed = nil
        close()
        callback?()
    }
}

// MARK: - SwiftUI Thumbnail View

private struct ThumbnailContentView: View {
    let image: NSImage
    let onOpen: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack {
            // 背景（暗い画像でも視認できるように）
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.windowBackgroundColor))
                .frame(width: 200, height: 200)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

            // 画像を正方形内に fit 表示
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if isHovering {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.3))
                    .frame(width: 200, height: 200)

                VStack {
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                    }
                    Spacer()
                }
                .frame(width: 200, height: 200)

                Text("クリックして編集")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
        }
        .padding(12)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { onOpen() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController {
    private let permission: ScreenCapturePermission

    init(permission: ScreenCapturePermission, onComplete: @escaping () -> Void) {
        self.permission = permission

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Screenshot セットアップ"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: OnboardingView(permission: permission, onComplete: onComplete)
        )
        window.center()

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    func showOnboarding() {
        showWindow(nil)
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
}

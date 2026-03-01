import SwiftUI

@main
struct ScreenshotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Screenshot", systemImage: "camera") {
            Button("範囲を選択して撮影") {
                appDelegate.captureOrShowOnboarding()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Divider()

            Button("終了") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }
}

/// アプリライフサイクル管理 — グローバルホットキーの登録/解除 + 権限オンボーディング
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let screenshotManager = ScreenshotManager()
    private let hotKeyManager = HotKeyManager()
    private let permission = ScreenCapturePermission()
    private var onboardingController: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !permission.isGranted {
            showOnboarding()
        }

        hotKeyManager.register { [weak self] in
            self?.captureOrShowOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
    }

    // MARK: - Capture with permission check

    func captureOrShowOnboarding() {
        permission.refresh()
        guard permission.isGranted else {
            showOnboarding()
            return
        }
        screenshotManager.captureScreenshot()
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        if onboardingController != nil {
            onboardingController?.showOnboarding()
            return
        }
        let controller = OnboardingWindowController(
            permission: permission,
            onComplete: { [weak self] in
                self?.dismissOnboarding()
            }
        )
        onboardingController = controller
        controller.showOnboarding()
    }

    private func dismissOnboarding() {
        onboardingController?.close()
        onboardingController = nil
    }
}

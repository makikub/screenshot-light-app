import SwiftUI

@main
struct ScreenshotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Screenshot", systemImage: "camera") {
            Button("範囲を選択して撮影") {
                appDelegate.screenshotManager.captureScreenshot()
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

/// アプリライフサイクル管理 — グローバルホットキーの登録/解除
final class AppDelegate: NSObject, NSApplicationDelegate {
    let screenshotManager = ScreenshotManager()
    private let hotKeyManager = HotKeyManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKeyManager.register { [weak self] in
            self?.screenshotManager.captureScreenshot()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
    }
}

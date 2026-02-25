import SwiftUI

@main
struct ScreenshotApp: App {
    @StateObject private var screenshotManager = ScreenshotManager()

    var body: some Scene {
        MenuBarExtra("Screenshot", systemImage: "camera") {
            Button("範囲を選択して撮影") {
                screenshotManager.captureScreenshot()
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

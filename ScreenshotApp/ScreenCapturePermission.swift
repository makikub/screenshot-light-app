import Combine
import CoreGraphics
import Foundation

@MainActor
final class ScreenCapturePermission: ObservableObject {
    @Published private(set) var isGranted: Bool

    private var timer: Timer?

    init() {
        isGranted = CGPreflightScreenCaptureAccess()
    }

    /// システム設定の「画面収録」ページを開いて権限をリクエスト
    func request() {
        CGRequestScreenCaptureAccess()
    }

    /// 権限状態を最新に更新（単発チェック）
    func refresh() {
        isGranted = CGPreflightScreenCaptureAccess()
    }

    /// ポーリング開始（0.5秒間隔で権限状態を監視）
    func startPolling() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    /// ポーリング停止
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}

@preconcurrency import Sparkle
import Combine

/// SPUUpdater.canCheckForUpdates を SwiftUI 向けに公開する ObservableObject ラッパー。
/// Sparkle 公式の推奨パターンに準拠。
@MainActor
final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var permission: ScreenCapturePermission
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            permissionSection
            Spacer()
            footerSection
        }
        .frame(width: 480, height: 340)
        .onAppear { permission.startPolling() }
        .onDisappear { permission.stopPolling() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Screenshot へようこそ")
                .font(.title2.bold())

            Text("スクリーンショットを撮影するために、\n以下の権限が必要です。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
        .padding(.bottom, 20)
    }

    // MARK: - Permission row

    private var permissionSection: some View {
        HStack(spacing: 12) {
            Image(systemName: permission.isGranted
                  ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(permission.isGranted ? .green : .red)
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .leading, spacing: 2) {
                Text("画面収録")
                    .font(.headline)
                Text("画面の内容をキャプチャするために必要です")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if permission.isGranted {
                Text("許可済み")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else {
                Button("設定を開く") {
                    permission.request()
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
        )
        .padding(.horizontal, 32)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Spacer()
            Button("始める") {
                onComplete()
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(!permission.isGranted)
        }
        .padding(20)
    }
}

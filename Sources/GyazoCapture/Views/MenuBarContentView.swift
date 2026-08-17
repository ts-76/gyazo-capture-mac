import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Menu("キャプチャモードを選択") {
            Button(AppConstants.CaptureMode.selection.buttonLabel) {
                coordinator.capture(mode: .selection)
            }
            .disabled(coordinator.isCapturing)

            Button(AppConstants.CaptureMode.fullScreen.buttonLabel) {
                coordinator.capture(mode: .fullScreen)
            }
            .disabled(coordinator.isCapturing)

            Button(AppConstants.CaptureMode.window.buttonLabel) {
                coordinator.capture(mode: .window)
            }
            .disabled(coordinator.isCapturing)

            Button(AppConstants.CaptureMode.previousSelection.buttonLabel) {
                coordinator.capture(mode: .previousSelection)
            }
            .disabled(coordinator.isCapturing || !coordinator.canCapturePreviousSelection)
        }

        ForEach(AppConstants.CaptureMode.allCases) { mode in
            Text("\(mode.title): \(AppConstants.captureHotKeyDescription(settings.captureHotKey(for: mode)))")
                .foregroundStyle(.secondary)
        }
        Text("デフォルトモード: \(settings.captureMode.title)")
            .foregroundStyle(.secondary)

        if let user = settings.connectedUser {
            Divider()
            Text("Gyazo: \(user.name)")
        } else {
            Divider()
            Text("Gyazo: 未接続")
                .foregroundStyle(.secondary)
        }

        if !coordinator.appStatus.isEmpty {
            Text(coordinator.appStatus)
                .foregroundStyle(.secondary)
        }

        Divider()
        if #available(macOS 14.0, *) {
            SettingsLink {
                Text("設定…")
            }
            .keyboardShortcut(",", modifiers: [.command])
        } else {
            Button("設定…") { SettingsWindowOpener.open() }
                .keyboardShortcut(",", modifiers: [.command])
        }
        Button("Gyazo Captureを終了") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: [.command])
    }
}

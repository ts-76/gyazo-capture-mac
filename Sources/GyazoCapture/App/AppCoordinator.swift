import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var isCapturing = false
    @Published var appStatus = ""

    let settings = SettingsStore()

    private let captureService = CaptureService()
    private let hotKeyService = GlobalHotKeyService()
    private let oauthService = OAuthService()
    private let gyazoClient = GyazoClient()
    private lazy var editorWindowController = EditorWindowController(coordinator: self)
    private var hasStarted = false

    var canCapturePreviousSelection: Bool {
        captureService.lastSelectionRect != nil
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        registerGlobalHotKeys()
        if settings.accessToken != nil {
            Task { await refreshConnectedUser() }
        }
    }

    func registerGlobalHotKeys() {
        for mode in AppConstants.CaptureMode.allCases {
            do {
                try registerGlobalHotKey(
                    settings.captureHotKey(for: mode),
                    for: mode
                )
            } catch {
                appStatus = "\(mode.title): \(error.localizedDescription)"
            }
        }
    }

    func setCaptureMode(_ mode: AppConstants.CaptureMode) {
        settings.setCaptureMode(mode)
    }

    func setCaptureHotKey(
        _ hotKey: AppConstants.CaptureHotKey,
        for mode: AppConstants.CaptureMode
    ) -> String? {
        let registrationID = mode.hotKeyRegistrationID
        let previousStoreValue = settings.captureHotKey(for: mode)
        let previousRegistered = hotKeyService.shortcut(for: registrationID)

        do {
            try settings.applyCaptureHotKey(hotKey, for: mode)
            try registerGlobalHotKey(hotKey, for: mode)
            appStatus = "\(mode.title)のショートカットを更新しました。"
            return nil
        } catch {
            settings.replaceCaptureHotKey(previousStoreValue, for: mode)
            do {
                if let previousRegistered {
                    try registerGlobalHotKey(previousRegistered, for: mode)
                } else {
                    hotKeyService.unregister(id: registrationID)
                }
            } catch {
                hotKeyService.unregister(id: registrationID)
                appStatus = "\(mode.title)のショートカットを復元できませんでした（\(error.localizedDescription)）。"
            }
            return error.localizedDescription
        }
    }

    func resetCaptureHotKey(for mode: AppConstants.CaptureMode) {
        let defaultHotKey = AppConstants.defaultCaptureHotKey(for: mode)
        appStatus = setCaptureHotKey(defaultHotKey, for: mode)
            ?? "\(mode.title)のショートカットをデフォルトに戻しました。"
    }

    func currentRegisteredHotKey(for mode: AppConstants.CaptureMode) -> AppConstants.CaptureHotKey? {
        hotKeyService.shortcut(for: mode.hotKeyRegistrationID)
    }

    func capture() {
        capture(mode: settings.captureMode)
    }

    func capture(mode: AppConstants.CaptureMode) {
        guard !isCapturing, !editorWindowController.isOpen else {
            appStatus = "編集中のキャプチャを完了してください。"
            return
        }
        isCapturing = true
        appStatus = "\(mode.title)を撮影してください。"

        Task {
            defer { isCapturing = false }
            do {
                let url = try await captureService.capture(mode: mode)
                guard let image = NSImage(contentsOf: url) else {
                    try? FileManager.default.removeItem(at: url)
                    throw CaptureError.outputMissing
                }
                let model = try EditorModel(sourceURL: url, image: image, settings: settings)
                editorWindowController.show(model: model)
                appStatus = ""
            } catch CaptureError.canceled {
                appStatus = ""
            } catch {
                appStatus = error.localizedDescription
            }
        }
    }

    private func registerGlobalHotKey(
        _ hotKey: AppConstants.CaptureHotKey,
        for mode: AppConstants.CaptureMode
    ) throws {
        try hotKeyService.register(
            id: mode.hotKeyRegistrationID,
            shortcut: hotKey
        ) { [weak self] in
            Task { @MainActor in self?.capture(mode: mode) }
        }
    }

    func connectGyazo() async {
        settings.statusMessage = "Gyazoの認証を開始しています…"
        do {
            try settings.saveCredentials()
            let token = try await oauthService.authenticate(
                clientID: settings.clientID,
                clientSecret: settings.clientSecret
            )
            try settings.storeAccessToken(token)
            let user = try await gyazoClient.currentUser(accessToken: token)
            settings.connectedUser = user
            settings.statusMessage = "\(user.name) として接続しました。"
        } catch {
            settings.statusMessage = error.localizedDescription
        }
    }

    func refreshConnectedUser() async {
        guard let token = settings.accessToken else { return }
        do {
            settings.connectedUser = try await gyazoClient.currentUser(accessToken: token)
        } catch {
            settings.statusMessage = "接続状態を確認できませんでした: \(error.localizedDescription)"
        }
    }

    func upload(model: EditorModel) async {
        guard !model.isUploading else { return }
        guard let token = settings.accessToken else {
            model.statusMessage = "先に設定でGyazoへ接続してください。"
            return
        }

        model.isUploading = true
        model.uploadFailed = false
        model.statusMessage = "編集後のPNGを作成しています…"
        defer { model.isUploading = false }

        do {
            let png = try renderPNG(from: model)
            model.statusMessage = "Gyazoへ送信しています…"
            let response = try await gyazoClient.upload(
                GyazoUploadRequest(
                    pngData: png,
                    description: model.descriptionText,
                    collectionID: model.collectionID.isEmpty ? nil : model.collectionID,
                    accessPolicy: model.accessPolicy
                ),
                accessToken: token
            )

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(response.permalinkURL.absoluteString, forType: .string)
            appStatus = "Gyazo URLをクリップボードへコピーしました。"
            model.uploadFailed = false
            editorWindowController.close(afterUploading: model)
        } catch {
            model.uploadFailed = true
            model.statusMessage = error.localizedDescription
        }
    }

    func copyCurrentImage(model: EditorModel) async {
        guard !model.isUploading else { return }
        model.statusMessage = "編集後のPNGを作成しています…"
        do {
            let png = try renderPNG(from: model)
            try ImageExportService.copyPNGToClipboard(png)
            model.statusMessage = "画像をクリップボードへコピーしました。"
        } catch {
            model.statusMessage = error.localizedDescription
        }
    }

    func saveCurrentImage(model: EditorModel) async {
        guard !model.isUploading else { return }
        model.statusMessage = "編集後のPNGを作成しています…"
        do {
            let png = try renderPNG(from: model)
            guard let destination = await selectSaveDestination() else {
                model.statusMessage = "保存をキャンセルしました。"
                return
            }
            try png.write(to: destination, options: .atomic)
            model.statusMessage = "保存しました: \(destination.lastPathComponent)"
        } catch {
            model.statusMessage = error.localizedDescription
        }
    }

    func editorDidClose() {
        // Keep the last upload result visible in the menu bar until the next action.
    }

    private func renderPNG(from model: EditorModel) throws -> Data {
        try ImageExportService.renderPNG(baseImage: model.baseImage, annotations: model.annotations)
    }

    private func selectSaveDestination() async -> URL? {
        await withCheckedContinuation { continuation in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType.png]
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = "capture_\(formatter.string(from: Date())).png"
            panel.begin { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }
}

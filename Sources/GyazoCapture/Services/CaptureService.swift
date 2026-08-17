import Foundation
import CoreGraphics

enum CaptureError: LocalizedError {
    case alreadyRunning
    case canceled
    case outputMissing
    case previousSelectionUnavailable

    var errorDescription: String? {
        switch self {
        case .alreadyRunning: return "キャプチャはすでに実行中です。"
        case .canceled: return "キャプチャをキャンセルしました。"
        case .outputMissing: return "キャプチャ画像を作成できませんでした。"
        case .previousSelectionUnavailable: return "前回の範囲が取得できないため再撮影できません。"
        }
    }
}

@MainActor
final class CaptureService {
    private var process: Process?
    private(set) var lastSelectionRect: CGRect?
    private let selectionOverlayService = SelectionOverlayService()

    func capture(mode: AppConstants.CaptureMode) async throws -> URL {
        guard process == nil else { throw CaptureError.alreadyRunning }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gyazo-capture-\(UUID().uuidString)")
            .appendingPathExtension("png")
        let preparedArguments = try await arguments(for: mode)

        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = preparedArguments + [outputURL.path]
            task.terminationHandler = { [weak self] finished in
                Task { @MainActor in
                    self?.process = nil
                    if finished.terminationStatus == 0,
                       FileManager.default.fileExists(atPath: outputURL.path) {
                        continuation.resume(returning: outputURL)
                    } else {
                        try? FileManager.default.removeItem(at: outputURL)
                        continuation.resume(throwing: CaptureError.canceled)
                    }
                }
            }

            do {
                process = task
                try task.run()
            } catch {
                process = nil
                continuation.resume(throwing: error)
            }
        }
    }

    func captureSelection() async throws -> URL {
        try await capture(mode: .selection)
    }

    func capturePreviousSelection() async throws -> URL {
        try await capture(mode: .previousSelection)
    }

    private func arguments(for mode: AppConstants.CaptureMode) async throws -> [String] {
        switch mode {
        case .selection:
            let rect = try await selectionOverlayService.selectRect()
            guard AppConstants.isSelectionRectUsable(rect) else {
                throw CaptureError.canceled
            }
            let normalizedRect = AppConstants.normalizeSelectionRect(rect)
            lastSelectionRect = normalizedRect
            return AppConstants.screencaptureRectangleArguments(from: normalizedRect)
        case .fullScreen:
            return ["-m", "-x", "-t", "png"]
        case .window:
            return ["-i", "-w", "-x", "-t", "png"]
        case .previousSelection:
            guard let rect = lastSelectionRect else {
                throw CaptureError.previousSelectionUnavailable
            }
            return AppConstants.screencaptureRectangleArguments(from: rect)
        }
    }
}

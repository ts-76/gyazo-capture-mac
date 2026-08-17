import AppKit
import CoreGraphics
import Foundation

enum SelectionOverlayError: LocalizedError {
    case canceled
    case noScreens

    var errorDescription: String? {
        switch self {
        case .canceled:
            return "範囲選択をキャンセルしました。"
        case .noScreens:
            return "画面情報を取得できませんでした。"
        }
    }
}

@MainActor
final class SelectionOverlayService {
    private var windows: [SelectionOverlayWindow] = []
    private var selectionStart: CGPoint?
    private var selectedRect: CGRect?
    private var continuation: CheckedContinuation<CGRect, Error>?
    private var globalKeyMonitor: Any?

    func selectRect() async throws -> CGRect {
        guard continuation == nil else { throw SelectionOverlayError.canceled }
        guard !NSScreen.screens.isEmpty else {
            throw SelectionOverlayError.noScreens
        }

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: SelectionOverlayError.canceled)
                return
            }
            self.selectionStart = nil
            self.selectedRect = nil
            self.continuation = continuation
            self.showOverlay()
        }
    }

    private func showOverlay() {
        NSApp.activate(ignoringOtherApps: true)
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                Task { @MainActor in
                    self?.cancelSelection()
                }
            }
        }
        windows = NSScreen.screens.map { screen in
            let window = SelectionOverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true

            let overlay = SelectionOverlayContentView()
            overlay.onStart = { [weak self] point in
                self?.startSelection(at: point)
            }
            overlay.onMove = { [weak self] point in
                self?.updateSelection(at: point)
            }
            overlay.onEnd = { [weak self] point in
                self?.finishSelection(at: point)
            }
            overlay.onCancel = { [weak self] in
                self?.cancelSelection()
            }
            window.contentView = overlay
            window.overlayView = overlay

            window.setFrame(screen.frame, display: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(overlay)
            return window
        }
    }

    private func startSelection(at point: CGPoint) {
        guard continuation != nil else { return }
        selectionStart = point
        selectedRect = CGRect(origin: point, size: .zero)
        updateSelectionVisual()
    }

    private func updateSelection(at point: CGPoint) {
        guard let start = selectionStart else { return }
        let rect = CGRect(
            x: min(start.x, point.x),
            y: min(start.y, point.y),
            width: abs(start.x - point.x),
            height: abs(start.y - point.y)
        )
        selectedRect = rect
        updateSelectionVisual()
    }

    private func finishSelection(at point: CGPoint) {
        guard let start = selectionStart else { return }
        let rect = CGRect(
            x: min(start.x, point.x),
            y: min(start.y, point.y),
            width: abs(start.x - point.x),
            height: abs(start.y - point.y)
        )
        if AppConstants.isSelectionRectUsable(rect) {
            selectedRect = AppConstants.normalizeSelectionRect(rect)
            completeSelection(AppConstants.normalizeSelectionRect(rect))
        } else {
            cancelSelection()
        }
    }

    private func updateSelectionVisual() {
        guard let rect = selectedRect else {
            windows.forEach { $0.overlayView?.setSelectionRect(nil) }
            return
        }
        windows.forEach { window in
            window.overlayView?.setSelectionRect(rect)
        }
    }

    private func completeSelection(_ rect: CGRect) {
        let continuation = self.continuation
        closeOverlay()
        continuation?.resume(returning: rect)
    }

    private func cancelSelection() {
        let continuation = self.continuation
        closeOverlay()
        continuation?.resume(throwing: SelectionOverlayError.canceled)
    }

    private func closeOverlay() {
        windows.forEach { $0.close() }
        windows.removeAll()
        continuation = nil
        selectionStart = nil
        selectedRect = nil
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
    }

}

private final class SelectionOverlayWindow: NSWindow {
    weak var overlayView: SelectionOverlayContentView?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class SelectionOverlayContentView: NSView {
    var onStart: ((CGPoint) -> Void)?
    var onMove: ((CGPoint) -> Void)?
    var onEnd: ((CGPoint) -> Void)?
    var onCancel: (() -> Void)?

    private var selectionRect: CGRect?

    override var acceptsFirstResponder: Bool { true }

    func setSelectionRect(_ globalRect: CGRect?) {
        guard let globalRect, let window else {
            selectionRect = nil
            setNeedsDisplay(bounds)
            return
        }
        let localRect = window.convertFromScreen(globalRect)
        selectionRect = localRect.intersection(bounds)
        setNeedsDisplay(bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.2).setFill()
        let path = NSBezierPath(rect: bounds)
        path.fill()

        guard let rect = selectionRect else { return }

        NSColor(calibratedWhite: 1, alpha: 0.95).setStroke()
        NSColor(calibratedWhite: 0, alpha: 0.35).setFill()
        let borderPath = NSBezierPath(rect: rect)
        borderPath.lineWidth = 2
        borderPath.stroke()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let point = globalPoint(from: event) else { return }
        onStart?(point)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let point = globalPoint(from: event) else { return }
        onMove?(point)
    }

    override func mouseUp(with event: NSEvent) {
        guard let point = globalPoint(from: event) else { return }
        onEnd?(point)
    }

    private func globalPoint(from event: NSEvent) -> CGPoint? {
        guard let window else { return nil }
        let windowPoint = event.locationInWindow
        return window.convertToScreen(NSRect(origin: windowPoint, size: .zero)).origin
    }
}

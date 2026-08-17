import AppKit
import SwiftUI

@MainActor
final class EditorWindowController: NSObject, NSWindowDelegate {
    private weak var coordinator: AppCoordinator?
    private var window: NSWindow?
    private var model: EditorModel?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    var isOpen: Bool { window?.isVisible == true }

    func show(model: EditorModel) {
        if let current = self.model, current !== model {
            current.cleanup()
        }
        window?.close()

        guard let coordinator else { return }
        self.model = model

        let rootView = CaptureEditorView(model: model)
            .environmentObject(coordinator)
            .environmentObject(coordinator.settings)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Gyazo Capture"
        window.contentViewController = hostingController
        window.minSize = NSSize(width: 900, height: 620)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func close(afterUploading model: EditorModel) {
        guard self.model === model else { return }
        window?.close()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        !(model?.isUploading ?? false)
    }

    func windowWillClose(_ notification: Notification) {
        model?.cleanup()
        model = nil
        window = nil
        coordinator?.editorDidClose()
    }
}

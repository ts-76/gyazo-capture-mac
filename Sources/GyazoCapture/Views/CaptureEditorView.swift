import SwiftUI

struct CaptureEditorView: View {
    @ObservedObject var model: EditorModel
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                EditorToolPaletteView(selection: $model.tool)
                Divider()
                HSplitView {
                    AnnotationCanvasView(model: model)
                        .frame(minWidth: 560)
                    EditorInspectorView(model: model)
                }
            }
        }
        .frame(minWidth: 952, minHeight: 620)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button { model.rotateCounterClockwise() } label: {
                Label("左に回転", systemImage: "rotate.left")
            }
            .help("画像を90度左回転")
            .labelStyle(.iconOnly)

            Button { model.rotateClockwise() } label: {
                Label("右に回転", systemImage: "rotate.right")
            }
            .help("画像を90度右回転")
            .labelStyle(.iconOnly)

            Divider().frame(height: 22)

            Button { model.undo() } label: { Label("取り消す", systemImage: "arrow.uturn.backward") }
                .disabled(!model.canUndo)
                .keyboardShortcut("z", modifiers: [.command])
                .labelStyle(.iconOnly)
            Button { model.redo() } label: { Label("やり直す", systemImage: "arrow.uturn.forward") }
                .disabled(!model.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .labelStyle(.iconOnly)

            Spacer()

            Button(role: .destructive) { model.deleteSelected() } label: {
                Label("削除", systemImage: "trash")
            }
            .disabled(model.selectedID == nil)
            .keyboardShortcut(.delete, modifiers: [])
            .labelStyle(.iconOnly)
        }
        .padding(10)
    }
}

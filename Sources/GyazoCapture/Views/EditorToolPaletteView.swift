import SwiftUI

struct EditorToolPaletteView: View {
    @Binding var selection: EditorTool

    private static let toolGroups: [[EditorTool]] = [
        [.select, .crop],
        [.rectangle, .ellipse, .line, .arrow],
        [.magnifier],
        [.text, .highlight],
        [.redaction, .blur, .mosaic]
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(Self.toolGroups.enumerated()), id: \.offset) { groupIndex, tools in
                if groupIndex > 0 {
                    Divider()
                        .frame(width: 28)
                        .padding(.vertical, 2)
                }

                ForEach(tools) { tool in
                    toolButton(tool)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(width: 52)
        .background(.regularMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("編集ツール")
    }

    private func toolButton(_ tool: EditorTool) -> some View {
        Button {
            selection = tool
        } label: {
            Image(systemName: tool.systemImage)
                .font(.system(size: 15, weight: selection == tool ? .semibold : .regular))
                .foregroundStyle(selection == tool ? Color.accentColor : Color.primary)
                .frame(width: 36, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selection == tool ? Color.accentColor.opacity(0.18) : Color.clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            selection == tool ? Color.accentColor.opacity(0.65) : Color.clear,
                            lineWidth: 1
                        )
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tool.label)
        .accessibilityLabel(tool.label)
        .accessibilityValue(selection == tool ? "選択中" : "")
    }
}

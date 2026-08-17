import SwiftUI

struct EditorInspectorView: View {
    @ObservedObject var model: EditorModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settings: SettingsStore

    private let palette = ["#FF3B30", "#FFCC00", "#34C759", "#007AFF", "#000000", "#FFFFFF"]

    private var activeAnnotationKind: AnnotationKind? {
        model.tool.annotationKind ?? model.selectedAnnotation?.kind
    }

    var body: some View {
        Form {
            Section("注釈") {
                if activeAnnotationKind?.isMask == true {
                    Stepper("強さ: \(Int(model.currentMaskStrength))", value: Binding(
                        get: { model.currentMaskStrength },
                        set: { model.applyMaskStrength($0) }
                    ), in: 4...40, step: 2)

                    Text(activeAnnotationKind == .blur
                         ? "選択範囲を滑らかにぼかします。"
                         : "選択範囲をピクセル状に粗くします。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 8) {
                        ForEach(palette, id: \.self) { hex in
                            Button {
                                model.applyColor(hex)
                            } label: {
                                Circle()
                                    .fill(Color(nsColor: NSColor(hex: hex) ?? .systemRed))
                                    .overlay(Circle().stroke(hex == model.currentColorHex ? .blue : .secondary, lineWidth: hex == model.currentColorHex ? 3 : 1))
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if model.selectedAnnotation?.kind == .text,
                       let id = model.selectedID {
                        TextField("テキスト", text: Binding(
                            get: { model.annotations.first(where: { $0.id == id })?.text ?? "" },
                            set: { model.setText($0, for: id) }
                        ), axis: .vertical)

                        Picker("文字サイズ", selection: Binding(
                            get: { model.currentFontSize },
                            set: { model.applyFontSize($0) }
                        )) {
                            ForEach(EditorStylePresets.fontSizeChoices(including: model.currentFontSize), id: \.self) { size in
                                Text("\(Int(size)) pt").tag(size)
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        Stepper("線幅: \(Int(model.currentLineWidth))", value: Binding(
                            get: { model.currentLineWidth },
                            set: { model.applyLineWidth($0) }
                        ), in: 1...20)
                        if activeAnnotationKind == .highlight {
                            Slider(value: Binding(
                                get: { model.currentFillOpacity },
                                set: { model.applyFillOpacity($0) }
                            ), in: 0.05...1, step: 0.05) {
                                Text("透過度")
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }

            Section("Gyazo") {
                TextField("説明・#タグ", text: $model.descriptionText, axis: .vertical)
                    .lineLimit(2...5)

                Picker("コレクション", selection: $model.collectionID) {
                    Text("指定なし").tag("")
                    ForEach(settings.collections) { preset in
                        Text(preset.name).tag(preset.collectionID)
                    }
                }

                Picker("公開範囲", selection: $model.accessPolicy) {
                    ForEach(GyazoAccessPolicy.allCases) { policy in
                        Text(policy.label).tag(policy)
                    }
                }
            }

            if !settings.isConnected {
                Section {
                    Label("Gyazoへ未接続です。設定で認証してください。", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Button("設定を開く") { SettingsWindowOpener.open() }
                }
            }

            if !model.statusMessage.isEmpty {
                Text(model.statusMessage)
                    .font(.caption)
                    .foregroundStyle(model.isUploading ? Color.secondary : Color.red)
                    .textSelection(.enabled)
            }

            Section {
                Button {
                    Task { await coordinator.copyCurrentImage(model: model) }
                } label: {
                    HStack {
                        Spacer()
                        Text("画像をクリップボードへコピー")
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(model.isUploading)

                Button {
                    Task { await coordinator.saveCurrentImage(model: model) }
                } label: {
                    HStack {
                        Spacer()
                        Text("PNGとして保存")
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(model.isUploading)

                Button {
                    Task { await coordinator.upload(model: model) }
                } label: {
                    HStack {
                        Spacer()
                        if model.isUploading { ProgressView().controlSize(.small) }
                        Text(model.isUploading
                             ? "アップロード中…"
                             : (model.uploadFailed ? "Gyazoへ再試行" : "Gyazoへアップロード")
                        )
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isUploading || !settings.isConnected)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 280, idealWidth: 300, maxWidth: 340)
    }
}

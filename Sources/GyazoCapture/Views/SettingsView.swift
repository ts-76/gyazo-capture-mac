import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        TabView {
            GyazoSettingsView()
                .environmentObject(coordinator)
                .tabItem { Label("Gyazo", systemImage: "person.crop.circle.badge.checkmark") }

            CollectionSettingsView()
                .environmentObject(coordinator)
                .tabItem { Label("コレクション", systemImage: "square.stack") }

            GeneralSettingsView()
                .environmentObject(coordinator)
                .tabItem { Label("一般", systemImage: "gearshape") }
        }
        .frame(width: 590, height: 460)
        .padding(16)
    }
}

private struct GyazoSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Form {
            Section("OAuthアプリ") {
                TextField("client ID", text: $settings.clientID)
                    .textFieldStyle(.roundedBorder)
                SecureField("client secret", text: $settings.clientSecret)
                    .textFieldStyle(.roundedBorder)

                LabeledContent("コールバックURL") {
                    HStack {
                        Text(AppConstants.callbackURL)
                            .textSelection(.enabled)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(AppConstants.callbackURL, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Section("接続") {
                if let user = settings.connectedUser {
                    LabeledContent("ユーザー", value: user.name)
                    LabeledContent("メール", value: user.email)
                } else if settings.isConnected {
                    Text("access tokenは保存されています。接続状態を確認してください。")
                } else {
                    Text("未接続")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("保存してGyazoに接続") {
                        Task { await coordinator.connectGyazo() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("接続状態を確認") {
                        Task { await coordinator.refreshConnectedUser() }
                    }
                    .disabled(!settings.isConnected)

                    Spacer()
                    Button("接続解除") {
                        do { try settings.disconnect() }
                        catch { settings.statusMessage = error.localizedDescription }
                    }
                    .disabled(!settings.isConnected)
                }
            }

            if !settings.statusMessage.isEmpty {
                Text(settings.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section {
                Button("ローカルの認証情報をすべて削除", role: .destructive) {
                    do { try settings.deleteAllCredentials() }
                    catch { settings.statusMessage = error.localizedDescription }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct CollectionSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var name = ""
    @State private var collectionInput = ""
    @State private var errorMessage = ""
    @State private var statusMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gyazoの公開APIにはコレクション一覧の取得機能がないため、作成済みコレクションのURLまたはIDを登録します。")
                .foregroundStyle(.secondary)

            HStack {
                Button("Gyazoでコレクションを確認") {
                    guard let url = URL(string: "https://gyazo.com/captures") else { return }
                    NSWorkspace.shared.open(url)
                }

                Button("クリップボードからURLを読み込む") {
                    importCollectionFromPasteboard()
                }

                Spacer()
            }

            List {
                ForEach(settings.collections) { preset in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(preset.name)
                            Text(preset.collectionID)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            settings.removeCollection(id: preset.id)
                        } label: {
                            Label("削除", systemImage: "trash")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                        .help("このMacのコレクション一覧から削除")
                    }
                }
                .onDelete(perform: settings.removeCollections)
            }
            .frame(minHeight: 160)

            HStack {
                TextField("表示名", text: $name)
                TextField("コレクションURLまたはID", text: $collectionInput)
                Button("追加") {
                    do {
                        try settings.addCollection(name: name, input: collectionInput)
                        name = ""
                        collectionInput = ""
                        errorMessage = ""
                        statusMessage = "コレクションを登録しました。"
                    } catch {
                        errorMessage = error.localizedDescription
                        statusMessage = ""
                    }
                }
            }

            Picker("既定のコレクション", selection: $settings.defaultCollectionID) {
                Text("指定なし").tag("")
                ForEach(settings.collections) { preset in
                    Text(preset.name).tag(preset.collectionID)
                }
            }
            .onChange(of: settings.defaultCollectionID) { _ in
                settings.persistPreferences()
            }

            if !errorMessage.isEmpty {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
            if !statusMessage.isEmpty {
                Text(statusMessage).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func importCollectionFromPasteboard() {
        guard let value = NSPasteboard.general.string(forType: .string),
              let collectionID = CollectionPreset.extractCollectionID(from: value) else {
            errorMessage = "クリップボードにGyazoのコレクションURLまたはIDがありません。"
            statusMessage = ""
            return
        }

        collectionInput = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = "コレクション \(collectionID.prefix(8))"
        }
        errorMessage = ""
        statusMessage = "URLを読み込みました。表示名を確認して「追加」を押してください。"
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var coordinator: AppCoordinator

    @State private var selectedCaptureMode: AppConstants.CaptureMode = AppConstants.defaultCaptureMode
    @State private var shortcutCaptureMode: AppConstants.CaptureMode = .selection
    @State private var selectedKeyCode: Int = AppConstants.defaultCaptureHotKey.keyCode
    @State private var selectedModifiers: Set<AppConstants.CaptureHotKeyModifier> = AppConstants.defaultCaptureHotKey.modifiers
    @State private var shortcutMessage = ""
    @State private var isReady = false

    var body: some View {
        Form {
            Section("キャプチャショートカット") {
                Picker("キャプチャ方式", selection: $shortcutCaptureMode) {
                    ForEach(AppConstants.CaptureMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Picker("キー", selection: $selectedKeyCode) {
                    ForEach(AppConstants.availableHotKeys) { key in
                        Text(key.label).tag(key.keyCode)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("修飾キー（1つ以上）")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(AppConstants.CaptureHotKeyModifier.allCases) { modifier in
                        Toggle(isOn: binding(for: modifier)) {
                            Text(modifier.label)
                        }
                    }
                }

                HStack {
                    Button("デフォルトに戻す") {
                        resetShortcut()
                    }
                    Spacer()
                    Text("現在: \(AppConstants.captureHotKeyDescription(settings.captureHotKey(for: shortcutCaptureMode)))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                if !shortcutMessage.isEmpty {
                    Text(shortcutMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("登録済みショートカット") {
                ForEach(AppConstants.CaptureMode.allCases) { mode in
                    LabeledContent(
                        mode.title,
                        value: AppConstants.captureHotKeyDescription(settings.captureHotKey(for: mode))
                    )
                }
            }

            Section("デフォルトのキャプチャモード") {
                Picker("デフォルトモード", selection: $selectedCaptureMode) {
                    ForEach(AppConstants.CaptureMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .onChange(of: selectedCaptureMode) { newMode in
                    coordinator.setCaptureMode(newMode)
                }
            }

            Section("キャプチャ") {
                Text("各方式には異なるショートカットを設定してください。macOS標準のスクリーンショットキーと重なる組み合わせは使用できません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("既定の公開範囲") {
                Picker("公開範囲", selection: $settings.defaultAccessPolicy) {
                    ForEach(GyazoAccessPolicy.allCases) { policy in
                        Text(policy.label).tag(policy)
                    }
                }
                .onChange(of: settings.defaultAccessPolicy) { _ in
                    settings.persistPreferences()
                }
            }

            Section("配布") {
                Text("このビルドはAd Hoc署名です。GitHubから取得した初回起動時は、システム設定の「プライバシーとセキュリティ」から「このまま開く」を選択してください。")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            selectedCaptureMode = settings.captureMode
            loadShortcut(for: shortcutCaptureMode)
            shortcutMessage = settings.captureHotKeyValidationMessage
            isReady = true
        }
        .onChange(of: shortcutCaptureMode) { newMode in
            guard isReady else { return }
            reloadShortcutEditor(for: newMode)
        }
        .onChange(of: selectedKeyCode) { newValue in
            guard isReady else { return }
            let candidate = AppConstants.CaptureHotKey(keyCode: newValue, modifiers: selectedModifiers)
            applyShortcut(candidate)
        }
        .onChange(of: selectedModifiers) { newModifiers in
            guard isReady else { return }
            let candidate = AppConstants.CaptureHotKey(keyCode: selectedKeyCode, modifiers: newModifiers)
            applyShortcut(candidate)
        }
    }

    private func applyShortcut(_ candidate: AppConstants.CaptureHotKey) {
        if let message = coordinator.setCaptureHotKey(candidate, for: shortcutCaptureMode) {
            shortcutMessage = message
            reloadShortcutEditor(for: shortcutCaptureMode, preservingMessage: true)
        } else {
            shortcutMessage = ""
            settings.captureHotKeyValidationMessage = ""
        }
    }

    private func resetShortcut() {
        let defaultHotKey = AppConstants.defaultCaptureHotKey(for: shortcutCaptureMode)
        if let message = coordinator.setCaptureHotKey(defaultHotKey, for: shortcutCaptureMode) {
            shortcutMessage = message
            reloadShortcutEditor(for: shortcutCaptureMode, preservingMessage: true)
        } else {
            shortcutMessage = ""
            reloadShortcutEditor(for: shortcutCaptureMode)
        }
    }

    private func loadShortcut(for mode: AppConstants.CaptureMode) {
        let hotKey = settings.captureHotKey(for: mode)
        selectedKeyCode = hotKey.keyCode
        selectedModifiers = hotKey.modifiers
    }

    private func reloadShortcutEditor(
        for mode: AppConstants.CaptureMode,
        preservingMessage: Bool = false
    ) {
        isReady = false
        loadShortcut(for: mode)
        if !preservingMessage { shortcutMessage = "" }
        DispatchQueue.main.async { isReady = true }
    }

    private func binding(for modifier: AppConstants.CaptureHotKeyModifier) -> Binding<Bool> {
        Binding(
            get: { selectedModifiers.contains(modifier) },
            set: { isOn in
                if isOn {
                    selectedModifiers.insert(modifier)
                } else {
                    selectedModifiers.remove(modifier)
                }
            }
        )
    }
}

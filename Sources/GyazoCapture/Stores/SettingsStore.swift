import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    enum Account {
        static let clientID = "gyazo.client-id"
        static let clientSecret = "gyazo.client-secret"
        static let accessToken = "gyazo.access-token"
    }

    @Published var clientID = ""
    @Published var clientSecret = ""
    @Published var connectedUser: GyazoUser?
    @Published var collections: [CollectionPreset] = []
    @Published var defaultCollectionID = ""
    @Published var defaultAccessPolicy: GyazoAccessPolicy = .anyone
    @Published var statusMessage = ""
    @Published var captureMode: AppConstants.CaptureMode = .selection
    @Published var captureHotKeys = AppConstants.defaultCaptureHotKeys
    @Published var captureHotKeyValidationMessage = ""

    private let keychain = KeychainStore(service: AppConstants.keychainService)
    private let defaults: UserDefaults
    private let collectionsKey = "collections"
    private let defaultCollectionKey = "defaultCollectionID"
    private let accessPolicyKey = "defaultAccessPolicy"
    private let captureModeKey = "captureMode"
    private let legacyCaptureHotKeyKey = "captureHotKey"
    private let captureHotKeysKey = "captureHotKeys.v2"

    init(defaults: UserDefaults = .standard, loadKeychain: Bool = true) {
        self.defaults = defaults
        load(loadKeychain: loadKeychain)
    }

    var accessToken: String? {
        try? keychain.read(account: Account.accessToken)
    }

    var isConnected: Bool { accessToken != nil }

    func saveCredentials() throws {
        let id = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !secret.isEmpty else {
            throw ValidationError("client IDとclient secretを入力してください。")
        }
        try keychain.write(id, account: Account.clientID)
        try keychain.write(secret, account: Account.clientSecret)
        clientID = id
        clientSecret = secret
    }

    func storeAccessToken(_ token: String) throws {
        try keychain.write(token, account: Account.accessToken)
        objectWillChange.send()
    }

    func disconnect() throws {
        try keychain.delete(account: Account.accessToken)
        connectedUser = nil
        statusMessage = "Gyazoとの接続を解除しました。"
        objectWillChange.send()
    }

    func deleteAllCredentials() throws {
        try keychain.delete(account: Account.accessToken)
        try keychain.delete(account: Account.clientSecret)
        try keychain.delete(account: Account.clientID)
        clientID = ""
        clientSecret = ""
        connectedUser = nil
        statusMessage = "ローカルの認証情報を削除しました。"
        objectWillChange.send()
    }

    func setCaptureMode(_ mode: AppConstants.CaptureMode) {
        captureMode = mode
        persistPreferences()
    }

    func captureHotKey(for mode: AppConstants.CaptureMode) -> AppConstants.CaptureHotKey {
        captureHotKeys[mode] ?? AppConstants.defaultCaptureHotKey(for: mode)
    }

    func validateCaptureHotKey(
        _ newHotKey: AppConstants.CaptureHotKey,
        for mode: AppConstants.CaptureMode
    ) throws {
        let keyCode = newHotKey.keyCode
        guard AppConstants.isValidKeyCode(keyCode) else {
            throw CaptureHotKeyError.invalidKey
        }
        guard !newHotKey.modifiers.isEmpty else {
            throw CaptureHotKeyError.emptyModifier
        }
        guard !AppConstants.isReservedScreenshotShortcut(newHotKey) else {
            throw CaptureHotKeyError.conflictWithSystemScreenshot
        }
        guard !captureHotKeys.contains(where: { $0.key != mode && $0.value == newHotKey }) else {
            throw CaptureHotKeyError.duplicateAssignment
        }
    }

    func replaceCaptureHotKey(
        _ newHotKey: AppConstants.CaptureHotKey,
        for mode: AppConstants.CaptureMode,
        persist: Bool = true
    ) {
        captureHotKeys[mode] = newHotKey
        captureHotKeyValidationMessage = ""
        if persist { persistPreferences() }
    }

    func applyCaptureHotKey(
        _ newHotKey: AppConstants.CaptureHotKey,
        for mode: AppConstants.CaptureMode
    ) throws {
        try validateCaptureHotKey(newHotKey, for: mode)
        captureHotKeys[mode] = newHotKey
        persistPreferences()
        captureHotKeyValidationMessage = ""
    }

    func resetCaptureHotKeyToDefault(for mode: AppConstants.CaptureMode) {
        captureHotKeys[mode] = AppConstants.defaultCaptureHotKey(for: mode)
        persistPreferences()
        captureHotKeyValidationMessage = ""
    }

    func addCollection(name: String, input: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ValidationError("表示名を入力してください。") }
        guard let id = CollectionPreset.extractCollectionID(from: input) else {
            throw ValidationError("GyazoのコレクションURLまたはIDを確認してください。")
        }
        if let index = collections.firstIndex(where: { $0.collectionID == id }) {
            collections[index].name = trimmedName
        } else {
            collections.append(CollectionPreset(name: trimmedName, collectionID: id))
        }
        persistCollections()
    }

    func removeCollections(at offsets: IndexSet) {
        let removedIDs = offsets.map { collections[$0].collectionID }
        for index in offsets.sorted(by: >) {
            collections.remove(at: index)
        }
        if removedIDs.contains(defaultCollectionID) { defaultCollectionID = "" }
        persistCollections()
    }

    func removeCollection(id: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        removeCollections(at: IndexSet(integer: index))
    }

    func persistPreferences() {
        defaults.set(defaultCollectionID, forKey: defaultCollectionKey)
        defaults.set(defaultAccessPolicy.rawValue, forKey: accessPolicyKey)
        defaults.set(captureMode.rawValue, forKey: captureModeKey)
        let encodedHotKeys = Dictionary(
            uniqueKeysWithValues: captureHotKeys.map { ($0.key.rawValue, $0.value) }
        )
        if let data = try? JSONEncoder().encode(encodedHotKeys) {
            defaults.set(data, forKey: captureHotKeysKey)
        }
        persistCollections()
    }

    private func load(loadKeychain: Bool) {
        if loadKeychain {
            clientID = (try? keychain.read(account: Account.clientID)) ?? ""
            clientSecret = (try? keychain.read(account: Account.clientSecret)) ?? ""
        }
        defaultCollectionID = defaults.string(forKey: defaultCollectionKey) ?? ""
        defaultAccessPolicy = GyazoAccessPolicy(rawValue: defaults.string(forKey: accessPolicyKey) ?? "") ?? .anyone
        captureMode = AppConstants.CaptureMode(rawValue: defaults.string(forKey: captureModeKey) ?? "") ?? .selection
        loadCaptureHotKeys()
        if let data = defaults.data(forKey: collectionsKey),
           let decoded = try? JSONDecoder().decode([CollectionPreset].self, from: data) {
            collections = decoded
        }
    }

    private func persistCollections() {
        if let data = try? JSONEncoder().encode(collections) {
            defaults.set(data, forKey: collectionsKey)
        }
        defaults.set(defaultCollectionID, forKey: defaultCollectionKey)
    }

    private func loadCaptureHotKeys() {
        var loaded = AppConstants.defaultCaptureHotKeys
        if let data = defaults.data(forKey: captureHotKeysKey),
           let stored = try? JSONDecoder().decode(
               [String: AppConstants.CaptureHotKey].self,
               from: data
           ) {
            for mode in AppConstants.CaptureMode.allCases {
                if let hotKey = stored[mode.rawValue], AppConstants.isValidCaptureHotKey(hotKey) {
                    loaded[mode] = hotKey
                }
            }
        } else if let data = defaults.data(forKey: legacyCaptureHotKeyKey),
                  let legacy = try? JSONDecoder().decode(AppConstants.CaptureHotKey.self, from: data),
                  AppConstants.isValidCaptureHotKey(legacy) {
            loaded[.selection] = legacy
        }
        captureHotKeys = sanitizedCaptureHotKeys(loaded)
    }

    private func sanitizedCaptureHotKeys(
        _ hotKeys: [AppConstants.CaptureMode: AppConstants.CaptureHotKey]
    ) -> [AppConstants.CaptureMode: AppConstants.CaptureHotKey] {
        var result: [AppConstants.CaptureMode: AppConstants.CaptureHotKey] = [:]
        var used: Set<AppConstants.CaptureHotKey> = []
        let fallbackHotKeys = AppConstants.CaptureMode.allCases.map {
            AppConstants.defaultCaptureHotKey(for: $0)
        }

        for mode in AppConstants.CaptureMode.allCases {
            let candidate = hotKeys[mode] ?? AppConstants.defaultCaptureHotKey(for: mode)
            let resolved = used.contains(candidate)
                ? fallbackHotKeys.first(where: { !used.contains($0) }) ?? candidate
                : candidate
            result[mode] = resolved
            used.insert(resolved)
        }
        return result
    }
}

struct ValidationError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum CaptureHotKeyError: LocalizedError {
    case invalidKey
    case emptyModifier
    case conflictWithSystemScreenshot
    case duplicateAssignment

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "対応キーを選択してください。"
        case .emptyModifier:
            return "修飾キー（Command/Control/Option/Shift）は1つ以上選択してください。"
        case .conflictWithSystemScreenshot:
            return "macOS標準ショートカット（⌘⇧3/4等）と衝突するため使用できません。"
        case .duplicateAssignment:
            return "同じショートカットが別のキャプチャ方式で使用されています。"
        }
    }
}

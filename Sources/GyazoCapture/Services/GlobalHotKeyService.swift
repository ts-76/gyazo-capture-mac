import Carbon
import Foundation

final class GlobalHotKeyService {
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private var actions: [UInt32: () -> Void] = [:]
    private var currentShortcuts: [UInt32: AppConstants.CaptureHotKey] = [:]

    func register(
        id: UInt32,
        shortcut: AppConstants.CaptureHotKey,
        action: @escaping () -> Void
    ) throws {
        try installEventHandlerIfNeeded()
        unregister(id: id)

        let hotKeyID = EventHotKeyID(signature: OSType(0x47595A43), id: id) // GYZC
        let modifiers = shortcut.modifiers
            .reduce(UInt32(0)) { partialResult, modifier in
                partialResult | modifier.carbonMask
            }
        var hotKeyRef: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr, let hotKeyRef else {
            throw HotKeyError.registrationFailed(registerStatus)
        }
        hotKeyRefs[id] = hotKeyRef
        actions[id] = action
        currentShortcuts[id] = shortcut
    }

    func shortcut(for id: UInt32) -> AppConstants.CaptureHotKey? {
        currentShortcuts[id]
    }

    func unregister(id: UInt32) {
        if let hotKeyRef = hotKeyRefs.removeValue(forKey: id) {
            UnregisterEventHotKey(hotKeyRef)
        }
        actions.removeValue(forKey: id)
        currentShortcuts.removeValue(forKey: id)
    }

    func unregister() {
        for hotKeyRef in hotKeyRefs.values {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()
        actions.removeAll()
        currentShortcuts.removeAll()
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
        eventHandlerRef = nil
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandlerRef == nil else { return }
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                let service = Unmanaged<GlobalHotKeyService>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                let parameterStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard parameterStatus == noErr,
                      let action = service.actions[hotKeyID.id] else {
                    return OSStatus(eventNotHandledErr)
                }
                action()
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard status == noErr else { throw HotKeyError.registrationFailed(status) }
    }

    deinit { unregister() }
}

enum HotKeyError: LocalizedError {
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let status):
            return "グローバルショートカットを登録できませんでした（\(status)）。"
        }
    }
}

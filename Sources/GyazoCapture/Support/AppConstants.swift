import AppKit
import Carbon
import CoreGraphics
import Foundation

enum AppConstants {
    static let appName = "Gyazo Capture"
    static let executableName = "GyazoCapture"
    static let bundleIdentifier = "com.toma7698.GyazoCapture"
    static var runtimeBundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? bundleIdentifier
    }
    static var keychainService: String {
        "\(runtimeBundleIdentifier).credentials.v2"
    }
    static var callbackScheme: String {
        runtimeBundleIdentifier.hasSuffix(".dev") ? "gyazocapture-dev" : "gyazocapture"
    }
    static let callbackURL = "\(callbackScheme)://oauth/callback"

    enum CaptureMode: String, CaseIterable, Codable, Hashable, Identifiable {
        case selection
        case fullScreen
        case window
        case previousSelection

        var id: String { rawValue }

        var title: String {
            switch self {
            case .selection: return "範囲選択"
            case .fullScreen: return "全画面"
            case .window: return "ウィンドウ"
            case .previousSelection: return "前回範囲"
            }
        }

        var buttonLabel: String {
            switch self {
            case .selection: return "範囲をキャプチャ"
            case .fullScreen: return "全画面をキャプチャ"
            case .window: return "ウィンドウをキャプチャ"
            case .previousSelection: return "前回範囲を再撮影"
            }
        }

        var hotKeyRegistrationID: UInt32 {
            switch self {
            case .selection: return 1
            case .fullScreen: return 2
            case .window: return 3
            case .previousSelection: return 4
            }
        }
    }

    enum CaptureHotKeyModifier: String, Codable, Hashable, CaseIterable, Identifiable {
        case command
        case shift
        case option
        case control

        var id: String { rawValue }

        var label: String {
            switch self {
            case .command: return "Command"
            case .shift: return "Shift"
            case .option: return "Option"
            case .control: return "Control"
            }
        }

        var symbol: String {
            switch self {
            case .command: return "⌘"
            case .shift: return "⇧"
            case .option: return "⌥"
            case .control: return "⌃"
            }
        }

        var carbonMask: UInt32 {
            switch self {
            case .command: return UInt32(cmdKey)
            case .shift: return UInt32(shiftKey)
            case .option: return UInt32(optionKey)
            case .control: return UInt32(controlKey)
            }
        }

        var sortOrder: Int {
            switch self {
            case .control: return 0
            case .option: return 1
            case .command: return 2
            case .shift: return 3
            }
        }
    }

    struct CaptureHotKey: Codable, Hashable {
        var keyCode: Int
        var modifiers: Set<CaptureHotKeyModifier>
    }

    struct CaptureHotKeyChoice: Codable, Hashable, Identifiable {
        let keyCode: Int
        let label: String
        var id: Int { keyCode }
    }

    static let defaultCaptureMode: CaptureMode = .selection
    static let defaultCaptureHotKeys: [CaptureMode: CaptureHotKey] = [
        .selection: CaptureHotKey(keyCode: 21, modifiers: [.control, .option, .command]),
        .fullScreen: CaptureHotKey(keyCode: 20, modifiers: [.control, .option, .command]),
        .window: CaptureHotKey(keyCode: 22, modifiers: [.control, .option, .command]),
        .previousSelection: CaptureHotKey(keyCode: 23, modifiers: [.control, .option, .command])
    ]
    static var defaultCaptureHotKey: CaptureHotKey {
        defaultCaptureHotKey(for: .selection)
    }
    static var defaultHotKeyDescription: String {
        captureHotKeyDescription(defaultCaptureHotKey)
    }

    static func defaultCaptureHotKey(for mode: CaptureMode) -> CaptureHotKey {
        defaultCaptureHotKeys[mode]!
    }

    static let screenshotReservedKeyCodes: Set<Int> = [18, 19, 20, 21, 22]
    static let minimumSelectionDimension: CGFloat = 1
    static let availableHotKeys: [CaptureHotKeyChoice] = [
        CaptureHotKeyChoice(keyCode: 0, label: "A"),
        CaptureHotKeyChoice(keyCode: 1, label: "S"),
        CaptureHotKeyChoice(keyCode: 2, label: "D"),
        CaptureHotKeyChoice(keyCode: 3, label: "F"),
        CaptureHotKeyChoice(keyCode: 4, label: "H"),
        CaptureHotKeyChoice(keyCode: 5, label: "G"),
        CaptureHotKeyChoice(keyCode: 6, label: "Z"),
        CaptureHotKeyChoice(keyCode: 7, label: "X"),
        CaptureHotKeyChoice(keyCode: 8, label: "C"),
        CaptureHotKeyChoice(keyCode: 9, label: "V"),
        CaptureHotKeyChoice(keyCode: 11, label: "B"),
        CaptureHotKeyChoice(keyCode: 12, label: "Q"),
        CaptureHotKeyChoice(keyCode: 13, label: "W"),
        CaptureHotKeyChoice(keyCode: 14, label: "E"),
        CaptureHotKeyChoice(keyCode: 15, label: "R"),
        CaptureHotKeyChoice(keyCode: 16, label: "Y"),
        CaptureHotKeyChoice(keyCode: 17, label: "T"),
        CaptureHotKeyChoice(keyCode: 18, label: "1"),
        CaptureHotKeyChoice(keyCode: 19, label: "2"),
        CaptureHotKeyChoice(keyCode: 20, label: "3"),
        CaptureHotKeyChoice(keyCode: 21, label: "4"),
        CaptureHotKeyChoice(keyCode: 22, label: "5"),
        CaptureHotKeyChoice(keyCode: 23, label: "6"),
        CaptureHotKeyChoice(keyCode: 24, label: "7"),
        CaptureHotKeyChoice(keyCode: 25, label: "8"),
        CaptureHotKeyChoice(keyCode: 26, label: "9"),
        CaptureHotKeyChoice(keyCode: 27, label: "0"),
        CaptureHotKeyChoice(keyCode: 35, label: "P"),
        CaptureHotKeyChoice(keyCode: 49, label: "Space"),
        CaptureHotKeyChoice(keyCode: 51, label: "Delete"),
        CaptureHotKeyChoice(keyCode: 53, label: "Escape"),
        CaptureHotKeyChoice(keyCode: 123, label: "←"),
        CaptureHotKeyChoice(keyCode: 124, label: "→"),
        CaptureHotKeyChoice(keyCode: 125, label: "↓"),
        CaptureHotKeyChoice(keyCode: 126, label: "↑"),
        CaptureHotKeyChoice(keyCode: 122, label: "F1"),
        CaptureHotKeyChoice(keyCode: 120, label: "F2"),
        CaptureHotKeyChoice(keyCode: 99, label: "F3"),
        CaptureHotKeyChoice(keyCode: 118, label: "F4"),
        CaptureHotKeyChoice(keyCode: 96, label: "F5"),
        CaptureHotKeyChoice(keyCode: 97, label: "F6"),
        CaptureHotKeyChoice(keyCode: 98, label: "F7"),
        CaptureHotKeyChoice(keyCode: 100, label: "F8"),
        CaptureHotKeyChoice(keyCode: 101, label: "F9"),
        CaptureHotKeyChoice(keyCode: 109, label: "F10"),
        CaptureHotKeyChoice(keyCode: 103, label: "F11"),
        CaptureHotKeyChoice(keyCode: 111, label: "F12")
    ]

    static var supportedHotKeyCodeSet: Set<Int> {
        Set(availableHotKeys.map(\.keyCode))
    }

    static func captureHotKeyDescription(_ hotKey: CaptureHotKey) -> String {
        let modifiers = hotKey.modifiers
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.symbol)
            .joined()
        let key = AppConstants.keyLabel(for: hotKey.keyCode)
        return "\(modifiers)\(key)"
    }

    static func keyLabel(for keyCode: Int) -> String {
        availableHotKeys.first(where: { $0.keyCode == keyCode })?.label
            ?? "Key \(keyCode)"
    }

    static func isReservedScreenshotShortcut(_ hotKey: CaptureHotKey) -> Bool {
        let isScreenshotCombo = hotKey.modifiers.contains(.command)
            && hotKey.modifiers.contains(.shift)
        return isScreenshotCombo && screenshotReservedKeyCodes.contains(hotKey.keyCode)
    }

    static func isValidCaptureHotKey(_ hotKey: CaptureHotKey) -> Bool {
        isValidKeyCode(hotKey.keyCode)
            && !hotKey.modifiers.isEmpty
            && !isReservedScreenshotShortcut(hotKey)
    }

    static func isValidKeyCode(_ keyCode: Int) -> Bool {
        supportedHotKeyCodeSet.contains(keyCode)
    }

    static func normalizeSelectionRect(_ rect: CGRect) -> CGRect {
        guard !rect.isNull else { return .null }
        let x = min(rect.minX, rect.maxX)
        let y = min(rect.minY, rect.maxY)
        let width = abs(rect.width)
        let height = abs(rect.height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func isSelectionRectUsable(_ rect: CGRect) -> Bool {
        let normalized = normalizeSelectionRect(rect)
        return normalized.width >= minimumSelectionDimension && normalized.height >= minimumSelectionDimension
    }

    static func screencaptureRectangleArguments(from rect: CGRect) -> [String] {
        screencaptureRectangleArguments(
            from: rect,
            primaryScreenMaxY: NSScreen.screens.first?.frame.maxY ?? 0
        )
    }

    static func screencaptureRectangleArguments(
        from rect: CGRect,
        primaryScreenMaxY: CGFloat
    ) -> [String] {
        let normalized = normalizeSelectionRect(rect)
        let topLeft = screencaptureTopLeftRect(
            for: normalized,
            primaryScreenMaxY: primaryScreenMaxY
        )
        let x = Int(normalized.origin.x)
        let y = Int(topLeft.origin.y)
        let width = Int(normalized.size.width)
        let height = Int(normalized.size.height)
        return ["-R", "\(x),\(y),\(width),\(height)", "-x", "-t", "png"]
    }

    static func screencaptureTopLeftRect(for rect: CGRect) -> CGRect {
        screencaptureTopLeftRect(
            for: rect,
            primaryScreenMaxY: NSScreen.screens.first?.frame.maxY ?? 0
        )
    }

    static func screencaptureTopLeftRect(for rect: CGRect, primaryScreenMaxY: CGFloat) -> CGRect {
        return CGRect(
            x: rect.origin.x,
            y: primaryScreenMaxY - (rect.origin.y + rect.height),
            width: rect.width,
            height: rect.height
        )
    }
}

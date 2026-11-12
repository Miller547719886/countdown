import AppKit
import Carbon.HIToolbox

struct GlobalHotKeyShortcut: Equatable {
    private static let keyCodePreferenceKey = "captureGlobalHotKeyKeyCode.v1"
    private static let modifierPreferenceKey = "captureGlobalHotKeyModifiers.v1"
    private static let keyLabelPreferenceKey = "captureGlobalHotKeyLabel.v1"

    private static let allowedModifierMask =
        UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey) | UInt32(shiftKey)

    static let defaultShortcut = GlobalHotKeyShortcut(
        keyCode: UInt32(kVK_ANSI_R),
        modifiers: UInt32(optionKey),
        keyLabel: "R"
    )

    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    var displayLabel: String {
        var symbols: [String] = []
        if modifiers & UInt32(controlKey) != 0 { symbols.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { symbols.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { symbols.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { symbols.append("⌘") }
        return "\(symbols.joined()) \(keyLabel)"
    }

    var isDefault: Bool {
        keyCode == Self.defaultShortcut.keyCode && modifiers == Self.defaultShortcut.modifiers
    }

    init?(event: NSEvent) {
        let modifiers = Self.carbonModifiers(from: event.modifierFlags)
        let keyCode = UInt32(event.keyCode)
        guard modifiers != 0,
              let keyLabel = Self.keyLabel(for: event),
              Self.isValid(keyCode: keyCode, modifiers: modifiers, keyLabel: keyLabel) else {
            return nil
        }

        self.init(keyCode: keyCode, modifiers: modifiers, keyLabel: keyLabel)
    }

    static func load(from defaults: UserDefaults = .standard) -> GlobalHotKeyShortcut {
        guard let storedKeyCode = defaults.object(forKey: keyCodePreferenceKey) as? NSNumber,
              let storedModifiers = defaults.object(forKey: modifierPreferenceKey) as? NSNumber,
              let keyLabel = defaults.string(forKey: keyLabelPreferenceKey),
              storedKeyCode.intValue >= 0,
              storedKeyCode.intValue <= Int(UInt16.max),
              storedModifiers.intValue >= 0,
              storedModifiers.uint32Value & ~allowedModifierMask == 0,
              storedModifiers.uint32Value != 0,
              !keyLabel.isEmpty else {
            return .defaultShortcut
        }

        guard Self.isValid(
            keyCode: storedKeyCode.uint32Value,
            modifiers: storedModifiers.uint32Value,
            keyLabel: keyLabel
        ) else {
            return .defaultShortcut
        }

        return GlobalHotKeyShortcut(
            keyCode: storedKeyCode.uint32Value,
            modifiers: storedModifiers.uint32Value,
            keyLabel: keyLabel
        )
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(NSNumber(value: keyCode), forKey: Self.keyCodePreferenceKey)
        defaults.set(NSNumber(value: modifiers), forKey: Self.modifierPreferenceKey)
        defaults.set(keyLabel, forKey: Self.keyLabelPreferenceKey)
    }

    private init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    private static func isValid(keyCode: UInt32, modifiers: UInt32, keyLabel: String) -> Bool {
        guard keyCode <= UInt32(UInt16.max),
              modifiers != 0,
              modifiers & ~Self.allowedModifierMask == 0,
              !keyLabel.isEmpty else {
            return false
        }

        return true
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        return modifiers
    }

    private static func keyLabel(for event: NSEvent) -> String? {
        if let characters = event.charactersIgnoringModifiers {
            let trimmed = characters.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count == 1,
               trimmed.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) {
                return trimmed.uppercased()
            }
        }

        switch event.keyCode {
        case UInt16(kVK_Space): return "Space"
        case UInt16(kVK_Return): return "Return"
        case UInt16(kVK_Tab): return "Tab"
        case UInt16(kVK_Delete): return "Delete"
        case UInt16(kVK_ForwardDelete): return "Forward Delete"
        case UInt16(kVK_LeftArrow): return "←"
        case UInt16(kVK_RightArrow): return "→"
        case UInt16(kVK_UpArrow): return "↑"
        case UInt16(kVK_DownArrow): return "↓"
        case UInt16(kVK_F1): return "F1"
        case UInt16(kVK_F2): return "F2"
        case UInt16(kVK_F3): return "F3"
        case UInt16(kVK_F4): return "F4"
        case UInt16(kVK_F5): return "F5"
        case UInt16(kVK_F6): return "F6"
        case UInt16(kVK_F7): return "F7"
        case UInt16(kVK_F8): return "F8"
        case UInt16(kVK_F9): return "F9"
        case UInt16(kVK_F10): return "F10"
        case UInt16(kVK_F11): return "F11"
        case UInt16(kVK_F12): return "F12"
        default: return nil
        }
    }
}

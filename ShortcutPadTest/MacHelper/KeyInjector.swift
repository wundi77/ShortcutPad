import AppKit
import Carbon

/// Übersetzt Zeichen und Sondertasten in virtuelle Tastencodes.
enum KeyMap {
    /// Muss auf dem Main-Thread laufen (Text Input Services).
    static func keyCode(for key: String) -> CGKeyCode? {
        if key.count > 1 {
            guard let named = NamedKey(rawValue: key) else { return nil }
            return virtualKey(for: named)
        }
        return characterMap()[key.lowercased()]
    }

    static func virtualKey(for key: NamedKey) -> CGKeyCode {
        switch key {
        case .returnKey: return 0x24
        case .tab: return 0x30
        case .space: return 0x31
        case .backspace: return 0x33
        case .escape: return 0x35
        case .forwardDelete: return 0x75
        case .home: return 0x73
        case .end: return 0x77
        case .pageUp: return 0x74
        case .pageDown: return 0x79
        case .left: return 0x7B
        case .right: return 0x7C
        case .down: return 0x7D
        case .up: return 0x7E
        case .f1: return 0x7A
        case .f2: return 0x78
        case .f3: return 0x63
        case .f4: return 0x76
        case .f5: return 0x60
        case .f6: return 0x61
        case .f7: return 0x62
        case .f8: return 0x64
        case .f9: return 0x65
        case .f10: return 0x6D
        case .f11: return 0x67
        case .f12: return 0x6F
        }
    }

    /// Zeichen → Taste für das aktuelle (ASCII-fähige) Tastaturlayout, nur ohne Zusatztasten.
    /// So ergibt "z" auf einem deutschen Layout die Taste, die dort wirklich "z" tippt.
    private static func characterMap() -> [String: CGKeyCode] {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return [:] }

        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPointer).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(layoutData) else { return [:] }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        let keyboardType = UInt32(LMGetKbdType())

        var map = [String: CGKeyCode]()
        for code in 0..<128 {
            var deadKeyState: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(
                layout,
                UInt16(code),
                UInt16(kUCKeyActionDown),
                0,
                keyboardType,
                0,
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
            guard status == noErr, length > 0 else { continue }
            let text = String(utf16CodeUnits: characters, count: length)
            if map[text] == nil {
                map[text] = CGKeyCode(code)
            }
        }
        return map
    }
}

/// Sendet Tastendrücke an das gerade aktive Programm.
/// Benötigt die Berechtigung „Bedienungshilfen“.
enum KeyInjector {
    private static let modifierKeys: [(modifier: KeyModifier, keyCode: CGKeyCode, flag: CGEventFlags)] = [
        (.control, 0x3B, .maskControl),
        (.option, 0x3A, .maskAlternate),
        (.shift, 0x38, .maskShift),
        (.command, 0x37, .maskCommand)
    ]

    static func send(keyCode: CGKeyCode, modifiers: Set<KeyModifier>) {
        let source = CGEventSource(stateID: .hidSystemState)
        let active = modifierKeys.filter { modifiers.contains($0.modifier) }
        var flags: CGEventFlags = []

        // Zusatztasten einzeln drücken – manche Programme (z. B. Adobe) werten
        // nur echte Modifier-Ereignisse aus, nicht allein die Flags am Tastenereignis.
        for entry in active {
            flags.insert(entry.flag)
            post(source: source, keyCode: entry.keyCode, down: true, flags: flags)
            usleep(3_000)
        }

        post(source: source, keyCode: keyCode, down: true, flags: flags)
        usleep(8_000)
        post(source: source, keyCode: keyCode, down: false, flags: flags)
        usleep(3_000)

        for entry in active.reversed() {
            flags.remove(entry.flag)
            post(source: source, keyCode: entry.keyCode, down: false, flags: flags)
            usleep(3_000)
        }
    }

    private static func post(source: CGEventSource?, keyCode: CGKeyCode, down: Bool, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down) else { return }
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }
}

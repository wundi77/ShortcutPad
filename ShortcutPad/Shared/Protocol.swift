import Foundation

// MARK: - Konstanten

enum PadProtocol {
    static let version = 1

    /// Auf diesem TCP-Port lauscht die iOS-App – ausschließlich auf 127.0.0.1.
    /// Der Mac erreicht ihn über das USB-Kabel (usbmuxd), nicht über WLAN.
    static let port: UInt16 = 49737
}

// MARK: - Tastenkürzel

enum KeyModifier: String, Codable, CaseIterable, Hashable, Identifiable {
    case control, option, shift, command

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .command: return "⌘"
        }
    }

    var title: String {
        switch self {
        case .control: return "Control"
        case .option: return "Option"
        case .shift: return "Shift"
        case .command: return "Command"
        }
    }
}

/// Sondertasten, die keinem einzelnen Zeichen entsprechen.
/// Der Mac-Helper übersetzt sie in feste virtuelle Tastencodes.
enum NamedKey: String, Codable, CaseIterable, Identifiable {
    case returnKey = "return"
    case tab, space, backspace, forwardDelete, escape
    case left, right, up, down, home, end, pageUp, pageDown
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .returnKey: return "↩"
        case .tab: return "⇥"
        case .space: return "␣"
        case .backspace: return "⌫"
        case .forwardDelete: return "⌦"
        case .escape: return "⎋"
        case .left: return "←"
        case .right: return "→"
        case .up: return "↑"
        case .down: return "↓"
        case .home: return "↖"
        case .end: return "↘"
        case .pageUp: return "⇞"
        case .pageDown: return "⇟"
        default: return rawValue.uppercased() // F1 … F12
        }
    }

    var title: String {
        switch self {
        case .returnKey: return "Return"
        case .tab: return "Tab"
        case .space: return "Leertaste"
        case .backspace: return "Löschen (⌫)"
        case .forwardDelete: return "Entf (⌦)"
        case .escape: return "Escape"
        case .left: return "Pfeil links"
        case .right: return "Pfeil rechts"
        case .up: return "Pfeil hoch"
        case .down: return "Pfeil runter"
        case .home: return "Pos1"
        case .end: return "Ende"
        case .pageUp: return "Bild ↑"
        case .pageDown: return "Bild ↓"
        default: return rawValue.uppercased() // F1 … F12
        }
    }
}

struct Shortcut: Codable, Equatable {
    /// Entweder ein einzelnes Zeichen ("b", "7", ",") oder der Rohwert eines `NamedKey` ("return", "f5" …).
    /// Zeichen werden auf dem Mac anhand des aktuellen Tastaturlayouts in die richtige Taste übersetzt
    /// (z. B. "z" auf einem deutschen Layout).
    var key: String
    var modifiers: Set<KeyModifier>

    var namedKey: NamedKey? {
        key.count > 1 ? NamedKey(rawValue: key) : nil
    }

    var isValid: Bool {
        key.count == 1 || namedKey != nil
    }

    var displayString: String {
        let order: [KeyModifier] = [.control, .option, .shift, .command]
        let prefix = order.filter { modifiers.contains($0) }.map { $0.symbol }.joined()
        return prefix + keyDisplay
    }

    var keyDisplay: String {
        if let named = namedKey { return named.symbol }
        let upper = key.uppercased()
        return upper.count == 1 ? upper : key
    }
}

// MARK: - Nachrichten (iOS ⇄ Mac)

struct HelloInfo: Codable {
    var protocolVersion: Int
    var deviceName: String
}

struct MacStatus: Codable {
    var macName: String
    var accessibilityGranted: Bool
    var frontmostApp: String
}

struct TriggerRequest: Codable {
    var id: UUID
    var shortcut: Shortcut
}

struct TriggerResult: Codable {
    var id: UUID
    var ok: Bool
    var message: String
}

enum PadMessage: Codable {
    case hello(HelloInfo)
    case status(MacStatus)
    case trigger(TriggerRequest)
    case result(TriggerResult)
}

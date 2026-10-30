import Foundation

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

// MARK: - Status

/// Was die Webseite über den Mac erfährt (`GET /api/status`).
struct MacStatus: Codable {
    var macName: String
    var accessibilityGranted: Bool
    var frontmostApp: String
    /// Zähler der Sets. Ändert er sich, lädt die Webseite die Sets neu (`GET /api/library`).
    var revision: Int
    /// Das Set, das gerade angezeigt werden soll (UUID als Text).
    var activeSetID: String?
    /// true, wenn das Set am Mac oder von der Webseite fixiert wurde (kein automatischer Wechsel).
    var pinned: Bool
}

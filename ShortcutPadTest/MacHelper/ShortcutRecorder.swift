import AppKit
import SwiftUI

/// Übersetzt Tastaturereignisse des Mac in ein Kürzel.
enum RecorderKeys {
    static func modifiers(from flags: NSEvent.ModifierFlags) -> Set<KeyModifier> {
        var result = Set<KeyModifier>()
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.command) { result.insert(.command) }
        return result
    }

    /// Sondertaste zu einem virtuellen Tastencode, falls es eine ist.
    static func namedKey(for keyCode: UInt16) -> NamedKey? {
        NamedKey.allCases.first { KeyMap.virtualKey(for: $0) == CGKeyCode(keyCode) }
    }

    /// Prüft, ob der Helper das Kürzel auf dem aktuellen Tastaturlayout senden kann. Gibt eine Warnung zurück, wenn nicht.
    /// Muss auf dem Main-Thread laufen.
    static func warning(for shortcut: Shortcut) -> String? {
        guard shortcut.isValid else { return "Das ist kein gültiges Kürzel." }
        if KeyMap.keyCode(for: shortcut.key) == nil {
            return "„\(shortcut.keyDisplay)“ lässt sich auf deinem Tastaturlayout nicht ohne Shift tippen und kann deshalb noch nicht gesendet werden."
        }
        return nil
    }

    /// Wandelt ein Tastenereignis in ein Kürzel um. Nil bei Tasten, die es nicht gibt (z. B. nur eine Zusatztaste).
    static func shortcut(from event: NSEvent) -> Shortcut? {
        let mods = modifiers(from: event.modifierFlags.intersection(.deviceIndependentFlagsMask))
        if let named = namedKey(for: event.keyCode) {
            return Shortcut(key: named.rawValue, modifiers: mods)
        }
        guard let characters = event.charactersIgnoringModifiers?.lowercased(), characters.count == 1 else {
            return nil
        }
        return Shortcut(key: characters, modifiers: mods)
    }
}

/// Dialog „Kürzel aufnehmen“: Tasten drücken oder von Hand wählen.
struct ShortcutRecorderSheet: View {
    let buttonName: String
    let setName: String
    let onDone: (Shortcut?) -> Void

    @State private var shortcut: Shortcut
    @State private var manual = false
    @State private var manualMods: Set<KeyModifier>
    @State private var manualKey: String
    @State private var manualNamed: NamedKey?
    @State private var warning: String? = nil
    @State private var monitor: Any? = nil

    init(buttonName: String, setName: String, initial: Shortcut, onDone: @escaping (Shortcut?) -> Void) {
        self.buttonName = buttonName
        self.setName = setName
        self.onDone = onDone
        _shortcut = State(initialValue: initial)
        _manualMods = State(initialValue: initial.modifiers)
        _manualKey = State(initialValue: initial.namedKey == nil ? initial.key : "")
        _manualNamed = State(initialValue: initial.namedKey)
    }

    var body: some View {
        SheetContainer(width: 520) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Kürzel aufnehmen")
                        .font(.system(size: 19, weight: .bold))
                    Text("Für den Button „\(buttonName)“ im Set \(setName). Drücke die Tastenkombination, die am Mac im vordersten Programm ausgelöst werden soll.")
                        .font(.system(size: 13.5))
                        .foregroundColor(Color(hex: 0xB4B7C0))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Picker("Eingabe", selection: $manual) {
                    Text("Aufnehmen").tag(false)
                    Text("Von Hand").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if manual {
                    manualEditor
                } else {
                    recordingZone
                }

                if let warning = warning {
                    Text(warning)
                        .font(.system(size: 12.5))
                        .foregroundColor(Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Buchstaben und Ziffern werden nach deinem Tastaturlayout übersetzt. Zeichen, die selbst Shift brauchen, etwa „/“, funktionieren noch nicht. Dafür gibt es eine Warnung statt eines stillen Fehlers.")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Spacer()
                    Button("Abbrechen") { onDone(nil) }
                        .buttonStyle(FlatButtonStyle(kind: .secondary))
                        .keyboardShortcut(.cancelAction)
                    Button("Übernehmen") { onDone(shortcut) }
                        .buttonStyle(FlatButtonStyle(kind: .primary))
                        .keyboardShortcut(.defaultAction)
                        .disabled(warning != nil || !shortcut.isValid)
                }
            }
        }
        .onAppear { startMonitor() }
        .onDisappear { stopMonitor() }
        .onChange(of: manual) { _ in
            warning = RecorderKeys.warning(for: shortcut)
        }
    }

    // MARK: Aufnahme

    private var recordingZone: some View {
        VStack(spacing: 14) {
            KeyCapsRow(shortcut: shortcut, large: true)
            HStack(spacing: 8) {
                Circle().fill(Color(hex: 0xFF6B6B)).frame(width: 7, height: 7)
                Text("Aufnahme läuft · Esc bricht ab")
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundColor(Color(hex: 0xD5D7DD))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 136)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0x1B2230)))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: 0x5B9BFF), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
        )
    }

    // MARK: Von Hand

    private var manualEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(KeyModifier.allCases) { modifier in
                    Button {
                        if manualMods.contains(modifier) {
                            manualMods.remove(modifier)
                        } else {
                            manualMods.insert(modifier)
                        }
                        applyManual()
                    } label: {
                        VStack(spacing: 2) {
                            Text(modifier.symbol).font(.system(size: 17))
                            Text(modifier.title).font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundColor(manualMods.contains(modifier) ? Color.white : Color(hex: 0xE6E8EC))
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(manualMods.contains(modifier) ? Theme.accent : Color(hex: 0x33353C))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Zeichen")
                    PadTextField(placeholder: "z. B. n", text: $manualKey)
                        .frame(width: 120)
                        .onChange(of: manualKey) { newValue in
                            if newValue.count > 1 { manualKey = String(newValue.suffix(1)) }
                            if !manualKey.isEmpty { manualNamed = nil }
                            applyManual()
                        }
                }
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("oder Sondertaste")
                    Picker("Sondertaste", selection: $manualNamed) {
                        Text("keine").tag(NamedKey?.none)
                        ForEach(NamedKey.allCases) { key in
                            Text(key.title).tag(NamedKey?.some(key))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                    .onChange(of: manualNamed) { newValue in
                        if newValue != nil { manualKey = "" }
                        applyManual()
                    }
                }
                Spacer()
            }

            KeyCapsRow(shortcut: shortcut)
        }
    }

    private func applyManual() {
        if let named = manualNamed {
            shortcut = Shortcut(key: named.rawValue, modifiers: manualMods)
        } else if let first = manualKey.lowercased().first {
            shortcut = Shortcut(key: String(first), modifiers: manualMods)
        } else {
            shortcut = Shortcut(key: "", modifiers: manualMods)
        }
        warning = shortcut.key.isEmpty ? nil : RecorderKeys.warning(for: shortcut)
    }

    // MARK: Ereignisse

    private func startMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if manual { return event }
            handle(event)
            return nil
        }
    }

    private func stopMonitor() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let escape = event.keyCode == 53
        if escape && flags.isDisjoint(with: [.command, .option, .control, .shift]) {
            onDone(nil)
            return
        }
        guard let recorded = RecorderKeys.shortcut(from: event) else {
            warning = "Diese Taste wird nicht unterstützt."
            return
        }
        shortcut = recorded
        warning = RecorderKeys.warning(for: recorded)
        manualMods = recorded.modifiers
        manualNamed = recorded.namedKey
        manualKey = recorded.namedKey == nil ? recorded.key : ""
    }
}

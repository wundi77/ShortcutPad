import AppKit
import SwiftUI

/// Inhalt des Menüleisten-Symbols: Status, vorderstes Programm, Set-Schnellwechsel und Fenster öffnen.
struct MenuBarView: View {
    @EnvironmentObject private var controller: HelperController
    @EnvironmentObject private var store: SetStore
    @Environment(\.openWindow) private var openWindow

    private var activeSet: PadSet? {
        store.set(withID: controller.activeSetID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            statusBlock
            divider
            frontBlock
            divider
            setList
            divider
            actions
        }
        .padding(10)
        .frame(width: 340)
        .foregroundColor(Theme.text)
        .preferredColorScheme(.dark)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(hex: 0x3A3C44))
            .frame(height: 1)
            .padding(.vertical, 6)
    }

    private var header: some View {
        HStack {
            Text("ShortcutPad")
                .font(.system(size: 15, weight: .heavy))
            Spacer()
            Text(controller.accessibilityGranted ? "bereit" : "Freigabe fehlt")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(controller.accessibilityGranted ? Theme.muted : Theme.danger)
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            statusLine(
                ok: controller.webRunning,
                text: controller.webRunning
                    ? "Webseite aktiv · \(controller.webPairedCount) Gerät(e) gekoppelt"
                    : "Webseite aus"
            )
            statusLine(
                ok: controller.webClientActive,
                text: controller.webClientActive ? "Gerät verbunden" : "Kein Gerät verbunden"
            )
            statusLine(
                ok: controller.accessibilityGranted,
                text: controller.accessibilityGranted ? "Bedienungshilfen freigegeben" : "Bedienungshilfen nicht freigegeben"
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private func statusLine(ok: Bool, text: String) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(ok ? Theme.live : Theme.muted)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: 0xD5D7DD))
        }
    }

    private var frontBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel("Vorne am Mac")
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.frontmostApp)
                        .font(.system(size: 14.5, weight: .semibold))
                        .lineLimit(1)
                    Text(activeSetText)
                        .font(.system(size: 12.5))
                        .foregroundColor(Color(hex: 0xA3A6AF))
                        .lineLimit(1)
                }
                Spacer()
                VStack(spacing: 4) {
                    Toggle("Fixieren", isOn: Binding(
                        get: { controller.pinnedSetID != nil },
                        set: { _ in controller.togglePin() }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    Text("Fixieren")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: 0xA3A6AF))
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private var activeSetText: String {
        guard let set = activeSet else { return "Kein Set aktiv" }
        let how = controller.pinnedSetID != nil ? "fixiert" : "automatisch gewählt"
        return "Set \(set.name), \(how)"
    }

    private var setList: some View {
        VStack(alignment: .leading, spacing: 2) {
            FieldLabel("Sets")
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
            ForEach(store.sets) { set in
                Button {
                    controller.selectSet(set.id)
                } label: {
                    HStack(spacing: 10) {
                        Circle().fill(set.color.color).frame(width: 10, height: 10)
                        Text(set.name).font(.system(size: 14))
                        Spacer()
                        if controller.activeSetID == set.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: 0x5B9BFF))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if controller.pinnedSetID != nil {
                Button {
                    controller.unpin()
                } label: {
                    Text("Wieder automatisch wählen")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: 0x6FA8FF))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 2) {
            menuItem("Editor öffnen", shortcut: "⌘E") {
                openWindow(id: "editor")
                NSApp.activate(ignoringOtherApps: true)
            }
            menuItem("Verbindung und Kopplung", shortcut: nil) {
                openWindow(id: "connection")
                NSApp.activate(ignoringOtherApps: true)
            }
            menuItem("ShortcutPad beenden", shortcut: "⌘Q") {
                NSApp.terminate(nil)
            }
        }
    }

    private func menuItem(_ title: String, shortcut: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 14))
                Spacer()
                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.muted)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

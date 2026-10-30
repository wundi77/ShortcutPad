import SwiftUI

@main
struct ShortcutPadHelperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = HelperController()
    @StateObject private var store = SetStore.shared

    var body: some Scene {
        // Hauptfenster zum Bearbeiten der Sets. Das Fenster darf geschlossen werden, der Dienst läuft weiter.
        Window("ShortcutPad", id: "editor") {
            EditorView()
                .environmentObject(controller)
                .environmentObject(store)
        }

        // Verbindung, Kopplung, Berechtigung und Protokoll. Der Titel wird in HelperController wiedererkannt.
        Window("Verbindung und Kopplung", id: "connection") {
            HelperView()
                .environmentObject(controller)
        }

        MenuBarExtra("ShortcutPad", systemImage: "square.grid.3x3.fill") {
            MenuBarView()
                .environmentObject(controller)
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}

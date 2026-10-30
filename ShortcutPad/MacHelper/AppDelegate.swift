import AppKit

/// Die App läuft als Menüleisten-Programm: kein Dock-Symbol (LSUIElement), keine Fenster beim Start.
/// Beim allerersten Start bleibt der Editor offen, damit man sich zurechtfindet; danach öffnet man ihn über das Menüleisten-Symbol.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let introKey = "ui.introShown"
    private static let startupWindowTitles = ["ShortcutPad", "Verbindung und Kopplung"]

    func applicationDidFinishLaunching(_ notification: Notification) {
        let firstStart = !UserDefaults.standard.bool(forKey: AppDelegate.introKey)
        UserDefaults.standard.set(true, forKey: AppDelegate.introKey)

        if firstStart {
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // SwiftUI legt die Fenster erst nach dem Start an. Deshalb zweimal schließen: sofort und kurz danach.
        for delay in [0.0, 0.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                AppDelegate.closeStartupWindows()
            }
        }
    }

    /// Ohne Dock-Symbol soll beim Schließen des letzten Fensters nichts beendet werden.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private static func closeStartupWindows() {
        for window in NSApp.windows where startupWindowTitles.contains(window.title) {
            window.close()
        }
    }
}

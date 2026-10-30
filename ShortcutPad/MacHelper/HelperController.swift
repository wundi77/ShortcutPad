import AppKit
import Combine
import SwiftUI
import SystemConfiguration

final class HelperController: ObservableObject {
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var frontmostApp = "–"
    /// Set, das gerade ans Pad ausgeliefert wird (automatisch nach vorderstem Programm oder fixiert).
    @Published private(set) var activeSetID: UUID?
    /// Vom Nutzer fixiertes Set. Solange gesetzt, wechselt das Pad nicht mit dem Programm.
    @Published private(set) var pinnedSetID: UUID?
    @Published private(set) var lastTrigger = "–"
    @Published private(set) var lastLocalKey = "–"
    @Published private(set) var logLines: [String] = []
    /// Selbsttest: Tasten, die in diesem Fenster ankommen, werden angezeigt und nicht weitergereicht.
    @Published var captureLocalKeys = false

    // Web-Variante (Seite im lokalen Netzwerk)
    /// Schalter in der Oberfläche; `didSet` startet bzw. stoppt den Webserver. Standard: aus.
    @Published var webEnabled = false {
        didSet {
            guard webEnabled != oldValue else { return }
            UserDefaults.standard.set(webEnabled, forKey: HelperController.webEnabledKey)
            applyWebState()
        }
    }
    @Published private(set) var webRunning = false
    @Published private(set) var webError: String?
    @Published private(set) var webAddresses: [String] = []
    /// Name des Macs im lokalen Netz („Mac-Studio.local“). Bleibt gleich, auch wenn sich die IP-Adresse ändert.
    @Published private(set) var webHostName: String?
    @Published private(set) var webPIN = ""
    @Published private(set) var webPairedCount = 0
    /// true, solange mindestens eine gekoppelte Webseite in den letzten Sekunden beim Mac nachgefragt hat.
    @Published private(set) var webClientActive = false

    private var macName = "Mac"

    private static let webEnabledKey = "web.enabled"
    private let webServer = WebServer()
    private let webAPI = WebAPI()
    private let injectLock = NSLock()

    let store = SetStore.shared
    private var lastExternalBundleID: String?
    private var storeObserver: AnyCancellable?

    init() {
        signal(SIGPIPE, SIG_IGN)
        macName = Host.current().localizedName ?? "Mac"
        frontmostApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "–"
        if let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier, id != Bundle.main.bundleIdentifier {
            lastExternalBundleID = id
        }
        refreshAccessibility(prompt: true)
        installObservers()
        installKeyMonitor()
        setupWeb()
        observeStore()
    }

    // MARK: Sets

    private func observeStore() {
        // $sets meldet vor der Änderung; über den Main-Queue-Hop ist der neue Stand dann sichtbar.
        storeObserver = store.$sets
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateActiveSet() }
        updateActiveSet()
    }

    /// Bestimmt, welches Set gerade aktiv ist: das fixierte, sonst das zum vordersten Programm passende, sonst das Rückfall-Set.
    private func updateActiveSet() {
        if let pinned = pinnedSetID, store.set(withID: pinned) == nil {
            pinnedSetID = nil
        }
        let target = pinnedSetID ?? store.setForApp(bundleID: lastExternalBundleID)?.id
        if target != activeSetID {
            activeSetID = target
            if let name = store.set(withID: target)?.name {
                addLog("Aktives Set: \(name)")
            }
        }
    }

    /// Wählt ein Set von Hand und fixiert es, bis „Automatisch“ gewählt wird.
    func selectSet(_ id: UUID) {
        pinnedSetID = id
        updateActiveSet()
    }

    func unpin() {
        pinnedSetID = nil
        updateActiveSet()
    }

    func togglePin() {
        if pinnedSetID != nil {
            unpin()
        } else if let id = activeSetID {
            selectSet(id)
        }
    }

    /// Alle Sets plus aktives Set für die Webseite. Darf von beliebigen Threads aufgerufen werden.
    func libraryPayload() -> PadLibraryPayload {
        onMainSync {
            PadLibraryPayload(
                revision: store.revision,
                sets: store.sets,
                activeSetID: activeSetID,
                pinned: pinnedSetID != nil
            )
        }
    }

    // MARK: Berechtigung

    func requestAccessibility() {
        refreshAccessibility(prompt: true)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshAccessibility(prompt: Bool) {
        let trusted: Bool
        if prompt {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            trusted = AXIsProcessTrustedWithOptions(options)
        } else {
            trusted = AXIsProcessTrusted()
        }
        if trusted != accessibilityGranted {
            accessibilityGranted = trusted
        }
    }

    // MARK: Beobachter

    private func installObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.frontmostApp = app?.localizedName ?? "–"
            if let id = app?.bundleIdentifier, id != Bundle.main.bundleIdentifier {
                self?.lastExternalBundleID = id
                self?.updateActiveSet()
            }
        }

        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshAccessibility(prompt: false)
            self?.refreshWebAddresses()
            self?.updateWebClientActivity()
        }
    }

    private func installKeyMonitor() {
        _ = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            // Nur im Verbindungsfenster auswerten, damit Eingaben im Editor nie verschluckt werden.
            let inConnectionWindow = event.window?.title == "Verbindung und Kopplung"
            if inConnectionWindow {
                self.lastLocalKey = Self.describe(event)
            }
            return (self.captureLocalKeys && inConnectionWindow) ? nil : event
        }
    }

    private static func describe(_ event: NSEvent) -> String {
        var text = ""
        if event.modifierFlags.contains(.control) { text += "⌃" }
        if event.modifierFlags.contains(.option) { text += "⌥" }
        if event.modifierFlags.contains(.shift) { text += "⇧" }
        if event.modifierFlags.contains(.command) { text += "⌘" }
        let characters = event.charactersIgnoringModifiers?.uppercased() ?? "?"
        return "\(text)\(characters)   (Tastencode \(event.keyCode))"
    }

    /// Einziger Weg zum Tastendruck: Kürzel prüfen, in Tastencode übersetzen und an das aktive Programm senden.
    /// Darf von beliebigen Threads aufgerufen werden.
    private func executeShortcut(_ shortcut: Shortcut, source: String) -> ShortcutOutcome {
        var ok = false
        let message: String

        if !AXIsProcessTrusted() {
            message = "Bedienungshilfen-Berechtigung fehlt – am Mac freigeben."
        } else if !shortcut.isValid {
            message = "Ungültiges Kürzel."
        } else if let code = onMainSync({ KeyMap.keyCode(for: shortcut.key) }) {
            let target = onMainSync { NSWorkspace.shared.frontmostApplication?.localizedName ?? "?" }
            injectLock.lock()
            KeyInjector.send(keyCode: code, modifiers: shortcut.modifiers)
            injectLock.unlock()
            ok = true
            message = "\(shortcut.displayString) an „\(target)“ gesendet"
        } else {
            message = "Taste „\(shortcut.key)“ gibt es im aktuellen Tastaturlayout nicht."
        }

        let summary = "[\(source)] \(shortcut.displayString)  \(ok ? "✓" : "✗")  \(message)"
        DispatchQueue.main.async { self.lastTrigger = summary }
        addLog(summary)
        return ShortcutOutcome(ok: ok, message: message)
    }

    // MARK: Web

    private func setupWeb() {
        webPIN = webAPI.pin
        webPairedCount = webAPI.pairedCount

        webAPI.statusProvider = { [weak self] in
            guard let self = self else {
                return MacStatus(macName: "Mac", accessibilityGranted: false, frontmostApp: "–", revision: 0, activeSetID: nil, pinned: false)
            }
            return self.onMainSync {
                MacStatus(
                    macName: self.macName,
                    accessibilityGranted: self.accessibilityGranted,
                    frontmostApp: self.frontmostApp,
                    revision: self.store.revision,
                    activeSetID: self.activeSetID?.uuidString,
                    pinned: self.pinnedSetID != nil
                )
            }
        }
        webAPI.executor = { [weak self] shortcut in
            self?.executeShortcut(shortcut, source: "Web") ?? ShortcutOutcome(ok: false, message: "Helper beendet")
        }
        webAPI.selectHandler = { [weak self] id in
            guard let self = self else { return false }
            return self.onMainSync { () -> Bool in
                if let id = id {
                    guard self.store.set(withID: id) != nil else { return false }
                    self.selectSet(id)
                } else {
                    self.unpin()
                }
                return true
            }
        }
        webAPI.libraryProvider = { [weak self] in
            self?.libraryPayload() ?? PadLibraryPayload(revision: 0, sets: [], activeSetID: nil, pinned: false)
        }
        webAPI.onLog = { [weak self] text in self?.addLog(text) }
        webAPI.onPairingsChanged = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.webPIN = self.webAPI.pin
                self.webPairedCount = self.webAPI.pairedCount
            }
        }
        webServer.handler = { [weak self] request in
            self?.webAPI.handle(request) ?? WebServer.Response.text("Nicht verfügbar", status: 503)
        }

        // Gespeicherter Zustand: löst über didSet das Starten aus.
        // Beim allerersten Start ist die Webseite an, damit QR-Code und Kopplungscode sofort sichtbar sind.
        // Danach gilt die letzte Einstellung. Zugriff geht weiterhin nur mit Kopplungscode bzw. Token.
        let stored = UserDefaults.standard.object(forKey: HelperController.webEnabledKey) as? Bool
        if stored ?? true {
            webEnabled = true
        }
    }

    private func applyWebState() {
        if webEnabled {
            do {
                try webServer.start(port: WebServer.defaultPort)
                webRunning = true
                webError = nil
                refreshWebAddresses(force: true)
                addLog("Webseite wird angeboten (Port \(WebServer.defaultPort))")
            } catch {
                webRunning = false
                webError = describe(error)
                addLog("Webserver konnte nicht starten: \(describe(error))")
                // Schalter wieder ausschalten (asynchron, damit didSet sauber neu läuft).
                DispatchQueue.main.async { self.webEnabled = false }
            }
        } else {
            webServer.stop()
            webRunning = false
            webAddresses = []
            addLog("Webseite wird nicht mehr angeboten")
        }
    }

    private func updateWebClientActivity() {
        let active = webEnabled && webAPI.clientSeenRecently
        if active != webClientActive {
            webClientActive = active
        }
    }

    private static func bonjourHostName() -> String? {
        guard let name = SCDynamicStoreCopyLocalHostName(nil) as String?, !name.isEmpty else { return nil }
        return name + ".local"
    }

    private func refreshWebAddresses(force: Bool = false) {
        guard webEnabled || force else { return }
        let host = HelperController.bonjourHostName()
        if host != webHostName {
            webHostName = host
        }
        let addresses = LocalNetwork.ipv4Addresses()
        if addresses != webAddresses {
            webAddresses = addresses
        }
    }

    /// Entfernt alle gekoppelten Geräte und erzeugt einen neuen Code.
    func resetWebPairings() {
        webAPI.resetPairings()
        addLog("Alle Web-Kopplungen gelöscht, neuer Code erzeugt")
    }

    /// Adresse, die in den QR-Code kommt: inklusive Code, damit das Koppeln automatisch läuft.
    /// Der QR-Code nutzt den Namen des Macs; er bleibt gleich, auch wenn der Router eine andere IP-Adresse vergibt.
    /// Ohne Namen wird die erste IP-Adresse genommen.
    var webQRText: String? {
        guard let host = webHostName ?? webAddresses.first else { return nil }
        return "http://\(host):\(WebServer.defaultPort)/#pin=\(webPIN)"
    }

    func webURL(for ip: String) -> String {
        "http://\(ip):\(WebServer.defaultPort)/"
    }

    // MARK: Hilfen

    private func onMainSync<T>(_ work: () -> T) -> T {
        if Thread.isMainThread { return work() }
        return DispatchQueue.main.sync(execute: work)
    }

    private func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func addLog(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let line = "\(formatter.string(from: Date()))  \(text)"
        DispatchQueue.main.async {
            self.logLines.append(line)
            if self.logLines.count > 80 {
                self.logLines.removeFirst(self.logLines.count - 80)
            }
        }
    }
}

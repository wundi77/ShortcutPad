import AppKit
import Combine
import SwiftUI

final class HelperController: ObservableObject {
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var attachedDevices: [Int: String] = [:]
    @Published private(set) var linkedDeviceName: String?
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
    @Published private(set) var webPIN = ""
    @Published private(set) var webPairedCount = 0

    private let stateLock = NSLock()
    private var attachedIDs = Set<Int>()
    private var sockets = [Int: FrameSocket]()
    private let sendQueue = DispatchQueue(label: "shortcutpad.send")
    private let watcher = USBMuxWatcher()
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
        startWatcher()
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

    /// Alle Sets plus aktives Set für iPad, iPhone und Webseite. Darf von beliebigen Threads aufgerufen werden.
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

    /// Löst ein Kürzel zum Ausprobieren aus. Ist das Programm des Sets geöffnet, kommt es vorher nach vorne.
    func test(_ shortcut: Shortcut, targetBundleID: String?) {
        var delay = 0.0
        if let id = targetBundleID,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first {
            app.activate(options: [])
            delay = 0.5
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            _ = self?.executeShortcut(shortcut, source: "Test")
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
            pushStatus()
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
            self?.pushStatus()
        }

        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshAccessibility(prompt: false)
            self?.refreshWebAddresses()
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

    // MARK: USB

    private func startWatcher() {
        watcher.onLog = { [weak self] text in self?.addLog(text) }
        watcher.onAttach = { [weak self] device in self?.deviceAttached(device) }
        watcher.onDetach = { [weak self] id in self?.deviceDetached(id) }
        watcher.onReset = { [weak self] in self?.devicesReset() }
        watcher.start()
    }

    private func isAttached(_ id: Int) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return attachedIDs.contains(id)
    }

    private func deviceAttached(_ device: USBMuxDevice) {
        stateLock.lock()
        let isNew = attachedIDs.insert(device.id).inserted
        stateLock.unlock()
        guard isNew else { return }

        DispatchQueue.main.async { self.attachedDevices[device.id] = device.serial }
        addLog("USB-Gerät erkannt (ID \(device.id))")

        let thread = Thread { [weak self] in
            self?.linkLoop(deviceID: device.id)
        }
        thread.name = "link-\(device.id)"
        thread.start()
    }

    private func deviceDetached(_ id: Int) {
        stateLock.lock()
        attachedIDs.remove(id)
        let socket = sockets[id]
        stateLock.unlock()
        socket?.shutdownConnection()
        DispatchQueue.main.async {
            self.attachedDevices[id] = nil
            if self.attachedDevices.isEmpty { self.linkedDeviceName = nil }
        }
    }

    private func devicesReset() {
        stateLock.lock()
        let ids = Array(attachedIDs)
        stateLock.unlock()
        for id in ids { deviceDetached(id) }
    }

    /// Hält die Verbindung zur iOS-App eines Geräts aufrecht: verbinden, zuhören, bei Abbruch neu versuchen.
    private func linkLoop(deviceID: Int) {
        var lastNote = ""
        while isAttached(deviceID) {
            var activeSocket: FrameSocket?
            do {
                let fd = try USBMux.openTunnel(deviceID: deviceID, port: PadProtocol.port)
                let socket = FrameSocket(fd: fd)
                activeSocket = socket
                stateLock.lock()
                sockets[deviceID] = socket
                stateLock.unlock()
                lastNote = ""
                addLog("Verbunden mit der iOS-App")

                try socket.send(.hello(HelloInfo(protocolVersion: PadProtocol.version, deviceName: macName)))
                pushStatus()

                while true {
                    let message = try socket.receive()
                    handle(message, from: socket)
                }
            } catch {
                let note = describe(error)
                if activeSocket != nil {
                    addLog("Verbindung beendet: \(note)")
                } else if note != lastNote {
                    addLog("iOS-App nicht erreichbar: \(note). App öffnen und Gerät entsperren.")
                    lastNote = note
                }
            }

            stateLock.lock()
            sockets[deviceID] = nil
            stateLock.unlock()
            DispatchQueue.main.async { self.linkedDeviceName = nil }

            Thread.sleep(forTimeInterval: 1.5)
        }
        addLog("USB-Gerät getrennt (ID \(deviceID))")
    }

    // MARK: Nachrichten

    private func handle(_ message: PadMessage, from socket: FrameSocket) {
        switch message {
        case .hello(let info):
            addLog("iOS-App meldet sich: \(info.deviceName)")
            DispatchQueue.main.async { self.linkedDeviceName = info.deviceName }
        case .trigger(let request):
            perform(request, via: socket)
        case .status, .result:
            break
        }
    }

    private func perform(_ request: TriggerRequest, via socket: FrameSocket) {
        let outcome = executeShortcut(request.shortcut, source: "USB")
        _ = try? socket.send(.result(TriggerResult(id: request.id, ok: outcome.ok, message: outcome.message)))
    }

    /// Gemeinsamer Weg für USB und Web: Kürzel prüfen, in Tastencode übersetzen und an das aktive Programm senden.
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
                return MacStatus(macName: "Mac", accessibilityGranted: false, frontmostApp: "–")
            }
            return self.onMainSync {
                MacStatus(
                    macName: self.macName,
                    accessibilityGranted: self.accessibilityGranted,
                    frontmostApp: self.frontmostApp
                )
            }
        }
        webAPI.executor = { [weak self] shortcut in
            self?.executeShortcut(shortcut, source: "Web") ?? ShortcutOutcome(ok: false, message: "Helper beendet")
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
        if UserDefaults.standard.bool(forKey: HelperController.webEnabledKey) {
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

    private func refreshWebAddresses(force: Bool = false) {
        guard webEnabled || force else { return }
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
    var webQRText: String? {
        guard let ip = webAddresses.first else { return nil }
        return "http://\(ip):\(WebServer.defaultPort)/#pin=\(webPIN)"
    }

    func webURL(for ip: String) -> String {
        "http://\(ip):\(WebServer.defaultPort)/"
    }

    private func pushStatus() {
        DispatchQueue.main.async {
            let status = MacStatus(
                macName: self.macName,
                accessibilityGranted: self.accessibilityGranted,
                frontmostApp: self.frontmostApp
            )
            self.stateLock.lock()
            let targets = Array(self.sockets.values)
            self.stateLock.unlock()
            self.sendQueue.async {
                for socket in targets {
                    _ = try? socket.send(.status(status))
                }
            }
        }
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

import SwiftUI
import UIKit

final class PadModel: ObservableObject {
    @Published var shortcut: Shortcut {
        didSet { saveShortcut() }
    }

    @Published private(set) var macConnected = false
    @Published private(set) var macName: String?
    @Published private(set) var accessibilityGranted: Bool?
    @Published private(set) var frontmostApp: String?
    @Published private(set) var serverNote: String?
    @Published private(set) var resultText: String?
    @Published private(set) var resultOK: Bool?

    private static let defaultsKey = "pad.shortcut.v1"
    private let server = PadServer()
    private var pendingID: UUID?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(Shortcut.self, from: data) {
            shortcut = saved
        } else {
            shortcut = Shortcut(key: "b", modifiers: [.command])
        }

        // Bildschirm anlassen, solange die App im Vordergrund ist (Bedienpult-Betrieb).
        UIApplication.shared.isIdleTimerDisabled = true

        server.onEvent = { [weak self] event in
            self?.handle(event)
        }

        // iOS beendet Sockets, sobald die App in den Hintergrund geht → beim Zurückkehren neu starten.
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.server.start()
        }
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.server.stop()
            self?.resetConnectionState()
        }

        server.start()
    }

    // MARK: Anzeige

    var detailText: String {
        if let note = serverNote, !macConnected {
            return note
        }
        guard macConnected else {
            return "Mac-Helper starten und dieses Gerät per Kabel anschließen (am Mac „Diesem Computer vertrauen“ bestätigen)."
        }
        var parts = [macName ?? "Mac"]
        parts.append("Ziel: " + (frontmostApp ?? "–"))
        if accessibilityGranted == false {
            parts.append("⚠︎ Bedienungshilfen am Mac nicht freigegeben")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Kürzel bearbeiten

    var isNamedKey: Bool {
        shortcut.key.count > 1
    }

    func setNamedMode(_ named: Bool) {
        if named {
            if shortcut.namedKey == nil { shortcut.key = NamedKey.returnKey.rawValue }
        } else if shortcut.key.count != 1 {
            shortcut.key = ""
        }
    }

    func setCharacter(_ text: String) {
        guard let last = text.last else {
            shortcut.key = ""
            return
        }
        shortcut.key = String(last).lowercased()
    }

    func setModifier(_ modifier: KeyModifier, enabled: Bool) {
        if enabled {
            shortcut.modifiers.insert(modifier)
        } else {
            shortcut.modifiers.remove(modifier)
        }
    }

    // MARK: Auslösen

    func trigger() {
        guard shortcut.isValid else { return }
        guard macConnected else {
            setResult("Kein Mac verbunden", ok: false)
            return
        }
        let request = TriggerRequest(id: UUID(), shortcut: shortcut)
        pendingID = request.id
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if !server.send(.trigger(request)) {
            setResult("Senden fehlgeschlagen", ok: false)
        }
    }

    // MARK: Ereignisse vom Server

    private func handle(_ event: PadServer.Event) {
        switch event {
        case .listening:
            serverNote = nil
        case .listenFailed(let reason):
            serverNote = "Listener-Fehler: \(reason)"
        case .connected:
            macConnected = true
            let hello = HelloInfo(protocolVersion: PadProtocol.version, deviceName: UIDevice.current.name)
            server.send(.hello(hello))
        case .disconnected:
            resetConnectionState()
        case .message(let message):
            handle(message)
        }
    }

    private func handle(_ message: PadMessage) {
        switch message {
        case .hello:
            break
        case .status(let status):
            macName = status.macName
            accessibilityGranted = status.accessibilityGranted
            frontmostApp = status.frontmostApp
        case .result(let result):
            guard result.id == pendingID else { return }
            setResult(result.message, ok: result.ok)
        case .trigger:
            break
        }
    }

    private func resetConnectionState() {
        macConnected = false
        macName = nil
        accessibilityGranted = nil
        frontmostApp = nil
    }

    private func setResult(_ text: String, ok: Bool) {
        resultText = text
        resultOK = ok
        UINotificationFeedbackGenerator().notificationOccurred(ok ? .success : .error)
    }

    private func saveShortcut() {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}

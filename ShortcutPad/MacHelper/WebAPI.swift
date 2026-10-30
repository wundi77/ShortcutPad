import Foundation

struct ShortcutOutcome {
    var ok: Bool
    var message: String
}

private struct WebTriggerRequest: Codable {
    var shortcut: Shortcut
}

private struct WebTriggerResult: Codable {
    var ok: Bool
    var message: String
}

private struct WebPairRequest: Codable {
    var pin: String
}

private struct WebPairResponse: Codable {
    var token: String
}

private struct WebError: Codable {
    var error: String
}

/// Routen und Zugriffsschutz für die Web-Variante.
///
/// Kopplung: Der Helper zeigt einen 6-stelligen Code. Die Webseite schickt ihn einmal an /api/pair
/// und erhält ein zufälliges Token, das sie bei jeder weiteren Anfrage im Header X-Pad-Token mitschickt.
/// Nach 5 falschen Codes sind Kopplungsversuche 30 Sekunden gesperrt.
final class WebAPI {
    private static let tokensKey = "web.tokens.v1"

    private let lock = NSLock()
    private var tokens: Set<String>
    private var currentPIN: String
    private var failedAttempts = 0
    private var lockedUntil = Date.distantPast
    private var lastClientSeen = Date.distantPast

    var statusProvider: () -> MacStatus = {
        MacStatus(macName: "Mac", accessibilityGranted: false, frontmostApp: "–")
    }
    var executor: (Shortcut) -> ShortcutOutcome = { _ in
        ShortcutOutcome(ok: false, message: "nicht verfügbar")
    }
    var libraryProvider: () -> PadLibraryPayload = {
        PadLibraryPayload(revision: 0, sets: [], activeSetID: nil, pinned: false)
    }
    var onLog: (String) -> Void = { _ in }
    var onPairingsChanged: () -> Void = {}

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: WebAPI.tokensKey) ?? []
        tokens = Set(saved)
        currentPIN = WebAPI.makePIN()
    }

    var pin: String {
        lock.lock()
        defer { lock.unlock() }
        return currentPIN
    }

    /// Hat sich in den letzten Sekunden eine gekoppelte Webseite gemeldet? Die Seite fragt alle 1,5 Sekunden nach.
    var clientSeenRecently: Bool {
        lock.lock()
        defer { lock.unlock() }
        return Date().timeIntervalSince(lastClientSeen) < 5
    }

    var pairedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return tokens.count
    }

    /// Entfernt alle Kopplungen und erzeugt einen neuen Code.
    func resetPairings() {
        lock.lock()
        tokens.removeAll()
        currentPIN = WebAPI.makePIN()
        failedAttempts = 0
        lockedUntil = Date.distantPast
        UserDefaults.standard.set([String](), forKey: WebAPI.tokensKey)
        lock.unlock()
        onPairingsChanged()
    }

    // MARK: Routen

    func handle(_ request: WebServer.Request) -> WebServer.Response {
        switch (request.method, request.path) {
        case ("GET", "/"), ("GET", "/index.html"):
            return .html(WebAssets.indexHTML)

        case ("POST", "/api/pair"):
            return pair(request)

        case ("GET", "/api/status"):
            guard isAuthorized(request) else { return unauthorized() }
            return .json(statusProvider())

        case ("GET", "/api/library"):
            guard isAuthorized(request) else { return unauthorized() }
            return .json(libraryProvider())

        case ("POST", "/api/trigger"):
            guard isAuthorized(request) else { return unauthorized() }
            guard let body = try? JSONDecoder().decode(WebTriggerRequest.self, from: request.body) else {
                return .json(WebError(error: "Ungültige Anfrage"), status: 400)
            }
            let outcome = executor(body.shortcut)
            return .json(WebTriggerResult(ok: outcome.ok, message: outcome.message))

        default:
            return .text("Nicht gefunden", status: 404)
        }
    }

    private func unauthorized() -> WebServer.Response {
        .json(WebError(error: "Nicht gekoppelt"), status: 401)
    }

    private func isAuthorized(_ request: WebServer.Request) -> Bool {
        guard let token = request.headers["x-pad-token"], !token.isEmpty else { return false }
        lock.lock()
        defer { lock.unlock() }
        let known = tokens.contains(token)
        if known { lastClientSeen = Date() }
        return known
    }

    private func pair(_ request: WebServer.Request) -> WebServer.Response {
        lock.lock()
        let isLocked = Date() < lockedUntil
        lock.unlock()
        if isLocked {
            return .json(WebError(error: "Zu viele Versuche. Bitte 30 Sekunden warten."), status: 429)
        }

        guard let body = try? JSONDecoder().decode(WebPairRequest.self, from: request.body) else {
            return .json(WebError(error: "Ungültige Anfrage"), status: 400)
        }

        lock.lock()
        if body.pin == currentPIN {
            failedAttempts = 0
            let token = WebAPI.makeToken()
            tokens.insert(token)
            UserDefaults.standard.set(Array(tokens), forKey: WebAPI.tokensKey)
            lock.unlock()
            onLog("Neues Gerät über die Webseite gekoppelt")
            onPairingsChanged()
            return .json(WebPairResponse(token: token))
        }

        failedAttempts += 1
        if failedAttempts >= 5 {
            failedAttempts = 0
            lockedUntil = Date().addingTimeInterval(30)
        }
        lock.unlock()
        return .json(WebError(error: "Falscher Code"), status: 403)
    }

    // MARK: Zufallswerte

    private static func makePIN() -> String {
        String(format: "%06d", Int.random(in: 0..<1_000_000))
    }

    private static func makeToken() -> String {
        (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }
}

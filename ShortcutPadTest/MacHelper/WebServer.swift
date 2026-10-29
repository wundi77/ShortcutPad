import Foundation
import Darwin

enum WebServerError: Error, LocalizedError {
    case socket(Int32)
    case bind(Int32)
    case listen(Int32)

    var errorDescription: String? {
        switch self {
        case .socket(let code):
            return "socket() fehlgeschlagen (errno \(code))"
        case .bind(let code):
            return code == EADDRINUSE ? "Port ist bereits belegt" : "bind() fehlgeschlagen (errno \(code))"
        case .listen(let code):
            return "listen() fehlgeschlagen (errno \(code))"
        }
    }
}

/// Minimaler HTTP-Server (HTTP/1.1, eine Anfrage pro Verbindung) auf allen Netzwerkschnittstellen.
/// Gedacht für ein vertrauenswürdiges Heim-/Büronetz: die Verbindung ist unverschlüsselt.
final class WebServer {
    static let defaultPort: UInt16 = 8765

    struct Request {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data
    }

    struct Response {
        var status: Int
        var contentType: String
        var body: Data

        static func html(_ text: String) -> Response {
            Response(status: 200, contentType: "text/html; charset=utf-8", body: Data(text.utf8))
        }

        static func text(_ text: String, status: Int) -> Response {
            Response(status: status, contentType: "text/plain; charset=utf-8", body: Data(text.utf8))
        }

        static func json<T: Encodable>(_ value: T, status: Int = 200) -> Response {
            let data = (try? JSONEncoder().encode(value)) ?? Data("{}".utf8)
            return Response(status: status, contentType: "application/json; charset=utf-8", body: data)
        }
    }

    /// Wird auf Hintergrund-Threads aufgerufen (mehrere Anfragen können gleichzeitig laufen).
    var handler: ((Request) -> Response)?

    private let lock = NSLock()
    private var listenFD: Int32 = -1
    private var generation = 0

    init() {
        signal(SIGPIPE, SIG_IGN)
    }

    // MARK: Steuerung

    func start(port: UInt16) throws {
        lock.lock()
        let alreadyRunning = listenFD >= 0
        lock.unlock()
        if alreadyRunning { return }

        // Nach einem schnellen Aus-/Einschalten kann der Port noch kurz belegt sein → mehrere Versuche.
        var fd: Int32 = -1
        var lastError = WebServerError.bind(0)
        for _ in 0..<10 {
            let candidate = Darwin.socket(AF_INET, SOCK_STREAM, 0)
            guard candidate >= 0 else { throw WebServerError.socket(errno) }

            var reuse: Int32 = 1
            setsockopt(candidate, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

            var address = sockaddr_in() // sin_addr bleibt 0 = alle Schnittstellen
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = port.bigEndian

            let result = withUnsafePointer(to: &address) { pointer -> Int32 in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(candidate, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if result == 0 {
                fd = candidate
                break
            }
            lastError = .bind(errno)
            Darwin.close(candidate)
            Thread.sleep(forTimeInterval: 0.1)
        }
        guard fd >= 0 else { throw lastError }

        guard Darwin.listen(fd, 16) == 0 else {
            let code = errno
            Darwin.close(fd)
            throw WebServerError.listen(code)
        }

        lock.lock()
        listenFD = fd
        generation += 1
        let gen = generation
        lock.unlock()

        let thread = Thread { [weak self] in
            self?.acceptLoop(fd: fd, generation: gen)
        }
        thread.name = "web-accept"
        thread.start()
    }

    func stop() {
        lock.lock()
        listenFD = -1
        generation += 1
        lock.unlock()
    }

    // MARK: Intern

    private func isCurrent(_ gen: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return listenFD >= 0 && generation == gen
    }

    private func acceptLoop(fd: Int32, generation gen: Int) {
        while isCurrent(gen) {
            var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let ready = poll(&descriptor, 1, 200)
            if ready <= 0 { continue }
            let client = Darwin.accept(fd, nil, nil)
            if client < 0 { continue }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(client)
            }
        }
        Darwin.close(fd)
    }

    private func handleClient(_ fd: Int32) {
        defer { Darwin.close(fd) }

        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))

        guard let request = readRequest(fd) else { return }
        let response = handler?(request) ?? Response.text("Nicht verfügbar", status: 503)
        respond(response, to: fd)
    }

    private func readRequest(_ fd: Int32) -> Request? {
        var data = [UInt8]()
        var chunk = [UInt8](repeating: 0, count: 4096)
        var end: Int?

        while end == nil {
            let n = chunk.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, 4096) }
            if n <= 0 { return nil }
            data.append(contentsOf: chunk[0..<n])
            if data.count > 16_384 { return nil }
            end = WebServer.headerEnd(in: data)
        }
        guard let headerEnd = end else { return nil }

        let headerText = String(decoding: data[0..<headerEnd], as: UTF8.self)
        var lines = headerText.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { return nil }
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count >= 2 else { return nil }

        let method = String(requestLine[0])
        let target = String(requestLine[1])
        let path = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            .first.map(String.init) ?? target

        var headers = [String: String]()
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        let length = Int(headers["content-length"] ?? "0") ?? 0
        guard length >= 0, length <= 8_192 else { return nil }

        var body = Array(data[(headerEnd + 4)...])
        while body.count < length {
            let n = chunk.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, 4096) }
            if n <= 0 { return nil }
            body.append(contentsOf: chunk[0..<n])
        }
        if body.count > length {
            body = Array(body[0..<length])
        }
        return Request(method: method, path: path, headers: headers, body: Data(body))
    }

    private static func headerEnd(in data: [UInt8]) -> Int? {
        guard data.count >= 4 else { return nil }
        var index = 0
        while index <= data.count - 4 {
            if data[index] == 13, data[index + 1] == 10, data[index + 2] == 13, data[index + 3] == 10 {
                return index
            }
            index += 1
        }
        return nil
    }

    private func respond(_ response: Response, to fd: Int32) {
        var head = "HTTP/1.1 \(response.status) \(WebServer.reason(response.status))\r\n"
        head += "Content-Type: \(response.contentType)\r\n"
        head += "Content-Length: \(response.body.count)\r\n"
        head += "Cache-Control: no-store\r\n"
        head += "Connection: close\r\n\r\n"
        var bytes = Array(head.utf8)
        bytes.append(contentsOf: response.body)
        try? FDIO.writeAll(fd: fd, bytes: bytes)
    }

    private static func reason(_ status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 429: return "Too Many Requests"
        case 503: return "Service Unavailable"
        default: return "Status"
        }
    }
}

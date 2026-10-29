import Foundation
import Darwin

/// Lauscht auf 127.0.0.1:<PadProtocol.port>. Der Mac-Helper verbindet sich über das USB-Kabel
/// (usbmuxd) mit diesem Port. Da nur die Loopback-Adresse gebunden ist, ist der Port
/// weder im WLAN noch sonst im Netzwerk erreichbar.
final class PadServer {
    enum Event {
        case listening
        case listenFailed(String)
        case connected
        case disconnected
        case message(PadMessage)
    }

    /// Wird immer auf dem Main-Thread aufgerufen.
    var onEvent: ((Event) -> Void)?

    private let lock = NSLock()
    private var running = false
    private var generation = 0
    private var current: FrameSocket?

    // MARK: Steuerung

    func start() {
        lock.lock()
        if running {
            lock.unlock()
            return
        }
        running = true
        generation += 1
        let gen = generation
        lock.unlock()

        let thread = Thread { [weak self] in
            self?.listenLoop(generation: gen)
        }
        thread.name = "pad-listener"
        thread.start()
    }

    func stop() {
        lock.lock()
        running = false
        generation += 1
        let old = current
        current = nil
        lock.unlock()
        old?.shutdownConnection()
    }

    @discardableResult
    func send(_ message: PadMessage) -> Bool {
        lock.lock()
        let socket = current
        lock.unlock()
        guard let socket = socket else { return false }
        do {
            try socket.send(message)
            return true
        } catch {
            return false
        }
    }

    // MARK: Intern

    private func isCurrent(_ gen: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return running && generation == gen
    }

    private func emit(_ event: Event) {
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
    }

    private func listenLoop(generation gen: Int) {
        let listenFD = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard listenFD >= 0 else {
            emit(.listenFailed("socket() fehlgeschlagen (errno \(errno))"))
            return
        }

        var reuse: Int32 = 1
        setsockopt(listenFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = PadProtocol.port.bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")

        // Nach einem schnellen Neustart kann der Port kurz noch belegt sein → ein paar Versuche.
        var bound = false
        var lastErrno: Int32 = 0
        for _ in 0..<12 {
            if !isCurrent(gen) {
                Darwin.close(listenFD)
                return
            }
            let result = withUnsafePointer(to: &address) { pointer -> Int32 in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(listenFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if result == 0 {
                bound = true
                break
            }
            lastErrno = errno
            Thread.sleep(forTimeInterval: 0.3)
        }

        guard bound, Darwin.listen(listenFD, 2) == 0 else {
            Darwin.close(listenFD)
            emit(.listenFailed("Port \(PadProtocol.port) nicht verfügbar (errno \(lastErrno != 0 ? lastErrno : errno))"))
            lock.lock()
            if generation == gen { running = false }
            lock.unlock()
            return
        }

        emit(.listening)

        while isCurrent(gen) {
            var pollDescriptor = pollfd(fd: listenFD, events: Int16(POLLIN), revents: 0)
            let ready = poll(&pollDescriptor, 1, 400)
            if ready <= 0 { continue }
            let clientFD = Darwin.accept(listenFD, nil, nil)
            if clientFD < 0 { continue }
            adopt(clientFD, generation: gen)
        }

        Darwin.close(listenFD)
    }

    private func adopt(_ clientFD: Int32, generation gen: Int) {
        let socket = FrameSocket(fd: clientFD)

        lock.lock()
        let previous = current
        current = socket
        lock.unlock()
        previous?.shutdownConnection()

        emit(.connected)

        let thread = Thread { [weak self] in
            self?.readLoop(socket)
        }
        thread.name = "pad-reader"
        thread.start()
    }

    private func readLoop(_ socket: FrameSocket) {
        do {
            while true {
                let message = try socket.receive()
                emit(.message(message))
            }
        } catch {
            // Verbindung beendet (Mac-Helper geschlossen, Kabel gezogen, …)
        }

        lock.lock()
        let wasCurrent = (current === socket)
        if wasCurrent { current = nil }
        lock.unlock()
        if wasCurrent { emit(.disconnected) }
    }
}

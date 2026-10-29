import Foundation
import Darwin

enum SocketError: Error, LocalizedError {
    case closed
    case io(Int32)
    case badFrame

    var errorDescription: String? {
        switch self {
        case .closed: return "Verbindung getrennt"
        case .io(let code): return "Socket-Fehler (errno \(code))"
        case .badFrame: return "Ungültiges Datenpaket"
        }
    }
}

/// Blockierende Ein-/Ausgabe auf einem Dateideskriptor.
enum FDIO {
    static func readExactly(fd: Int32, count: Int) throws -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: count)
        var offset = 0
        while offset < count {
            let n = buffer.withUnsafeMutableBytes { raw -> Int in
                Darwin.read(fd, raw.baseAddress! + offset, count - offset)
            }
            if n > 0 {
                offset += n
            } else if n == 0 {
                throw SocketError.closed
            } else if errno == EINTR {
                continue
            } else {
                throw SocketError.io(errno)
            }
        }
        return buffer
    }

    static func writeAll(fd: Int32, bytes: [UInt8]) throws {
        var offset = 0
        while offset < bytes.count {
            let n = bytes.withUnsafeBytes { raw -> Int in
                Darwin.write(fd, raw.baseAddress! + offset, bytes.count - offset)
            }
            if n > 0 {
                offset += n
            } else if n < 0 && errno == EINTR {
                continue
            } else {
                throw SocketError.io(errno)
            }
        }
    }
}

/// Längenpräfixierte JSON-Nachrichten über einen verbundenen Socket:
/// [4 Byte Länge, Big-Endian][JSON-Daten]
final class FrameSocket {
    private let fd: Int32
    private let writeLock = NSLock()

    init(fd: Int32) {
        self.fd = fd
        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
    }

    deinit {
        Darwin.close(fd)
    }

    func send(_ message: PadMessage) throws {
        let json = try JSONEncoder().encode(message)
        let length = UInt32(json.count)
        var frame = [UInt8]()
        frame.reserveCapacity(4 + json.count)
        frame.append(UInt8((length >> 24) & 0xFF))
        frame.append(UInt8((length >> 16) & 0xFF))
        frame.append(UInt8((length >> 8) & 0xFF))
        frame.append(UInt8(length & 0xFF))
        frame.append(contentsOf: json)

        writeLock.lock()
        defer { writeLock.unlock() }
        try FDIO.writeAll(fd: fd, bytes: frame)
    }

    func receive() throws -> PadMessage {
        let header = try FDIO.readExactly(fd: fd, count: 4)
        let b0 = Int(header[0]) << 24
        let b1 = Int(header[1]) << 16
        let b2 = Int(header[2]) << 8
        let b3 = Int(header[3])
        let length = b0 | b1 | b2 | b3
        guard length > 0, length <= 65_536 else { throw SocketError.badFrame }
        let body = try FDIO.readExactly(fd: fd, count: length)
        do {
            return try JSONDecoder().decode(PadMessage.self, from: Data(body))
        } catch {
            throw SocketError.badFrame
        }
    }

    /// Weckt einen Thread, der gerade in `receive()` blockiert. Der Deskriptor selbst
    /// wird erst in `deinit` geschlossen, wenn niemand mehr darauf zugreift.
    func shutdownConnection() {
        Darwin.shutdown(fd, SHUT_RDWR)
    }
}

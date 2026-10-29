import Foundation
import Darwin

struct USBMuxDevice {
    let id: Int
    let serial: String
}

enum USBMuxError: Error, LocalizedError {
    case unavailable(String)
    case protocolError(String)
    case refused(Int)

    var errorDescription: String? {
        switch self {
        case .unavailable(let detail):
            return "usbmuxd nicht erreichbar (\(detail))"
        case .protocolError(let detail):
            return "usbmuxd-Protokollfehler (\(detail))"
        case .refused(let code):
            return "Verbindung abgelehnt (Code \(code))"
        }
    }
}

/// Minimaler Client für den macOS-Dienst `usbmuxd`, der auch Xcode für USB-Geräte nutzt.
///
/// Ablauf:
///  1. Unix-Socket /var/run/usbmuxd öffnen
///  2. "Listen" → Attached/Detached-Meldungen für USB-Geräte
///  3. Pro Gerät eine *neue* Socket-Verbindung öffnen, "Connect" mit Geräte-ID und Port senden.
///     Nach erfolgreichem Result ist dieser Socket ein roher TCP-Tunnel zum Port auf dem Gerät.
enum USBMux {
    static let socketPath = "/var/run/usbmuxd"
    private static let clientName = "ShortcutPad"

    static func openSocket() throws -> Int32 {
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw USBMuxError.unavailable("socket() errno \(errno)") }

        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketPath.utf8CString)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count <= capacity else {
            Darwin.close(fd)
            throw USBMuxError.unavailable("Pfad zu lang")
        }
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            for (index, byte) in pathBytes.enumerated() {
                raw[index] = UInt8(bitPattern: byte)
            }
        }
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)

        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &address) { pointer -> Int32 in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, size)
            }
        }
        guard result == 0 else {
            let code = errno
            Darwin.close(fd)
            throw USBMuxError.unavailable("connect() errno \(code)")
        }
        return fd
    }

    // MARK: Pakete

    static func send(fd: Int32, tag: UInt32, _ message: [String: Any]) throws {
        let payload = try PropertyListSerialization.data(fromPropertyList: message, format: .xml, options: 0)
        var packet = [UInt8]()
        packet.reserveCapacity(16 + payload.count)
        appendLE(&packet, UInt32(16 + payload.count)) // Gesamtlänge
        appendLE(&packet, 1)                          // Version 1 = Plist-Protokoll
        appendLE(&packet, 8)                          // Nachrichtentyp 8 = Plist
        appendLE(&packet, tag)
        packet.append(contentsOf: payload)
        try FDIO.writeAll(fd: fd, bytes: packet)
    }

    static func readPacket(fd: Int32) throws -> [String: Any] {
        let header = try FDIO.readExactly(fd: fd, count: 16)
        let length = Int(readLE(header, at: 0))
        guard length >= 16, length <= 1_048_576 else {
            throw USBMuxError.protocolError("Paketlänge \(length)")
        }
        let body = try FDIO.readExactly(fd: fd, count: length - 16)
        let object = try PropertyListSerialization.propertyList(from: Data(body), options: [], format: nil)
        guard let dictionary = object as? [String: Any] else {
            throw USBMuxError.protocolError("keine Plist-Antwort")
        }
        return dictionary
    }

    private static func appendLE(_ buffer: inout [UInt8], _ value: UInt32) {
        buffer.append(UInt8(value & 0xFF))
        buffer.append(UInt8((value >> 8) & 0xFF))
        buffer.append(UInt8((value >> 16) & 0xFF))
        buffer.append(UInt8((value >> 24) & 0xFF))
    }

    private static func readLE(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        let b0 = UInt32(bytes[offset])
        let b1 = UInt32(bytes[offset + 1]) << 8
        let b2 = UInt32(bytes[offset + 2]) << 16
        let b3 = UInt32(bytes[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }

    // MARK: Tunnel

    /// Öffnet einen TCP-Tunnel zu `port` auf dem USB-Gerät und liefert den (nun rohen) Socket.
    static func openTunnel(deviceID: Int, port: UInt16) throws -> Int32 {
        let fd = try openSocket()
        do {
            try send(fd: fd, tag: 1, [
                "MessageType": "Connect",
                "ClientVersionString": clientName,
                "ProgName": clientName,
                "kLibUSBMuxVersion": 3,
                "DeviceID": deviceID,
                // Portnummer in Netzwerk-Byte-Reihenfolge, wie von usbmuxd erwartet
                "PortNumber": Int(port.bigEndian)
            ])
            let reply = try readPacket(fd: fd)
            guard (reply["MessageType"] as? String) == "Result" else {
                throw USBMuxError.protocolError("unerwartete Antwort")
            }
            let number = reply["Number"] as? Int ?? -1
            guard number == 0 else { throw USBMuxError.refused(number) }
            return fd
        } catch {
            Darwin.close(fd)
            throw error
        }
    }

    // MARK: Listen

    static func sendListen(fd: Int32) throws {
        try send(fd: fd, tag: 1, [
            "MessageType": "Listen",
            "ClientVersionString": clientName,
            "ProgName": clientName,
            "kLibUSBMuxVersion": 3
        ])
    }
}

/// Meldet per USB angeschlossene Geräte (Attached/Detached).
final class USBMuxWatcher {
    var onAttach: ((USBMuxDevice) -> Void)?
    var onDetach: ((Int) -> Void)?
    /// Verbindung zu usbmuxd abgebrochen → bisherige Geräteliste ist ungültig.
    var onReset: (() -> Void)?
    var onLog: ((String) -> Void)?

    private var started = false

    func start() {
        guard !started else { return }
        started = true
        let thread = Thread { [weak self] in
            self?.loop()
        }
        thread.name = "usbmux-watcher"
        thread.start()
    }

    private func loop() {
        var lastError = ""
        while true {
            do {
                let fd = try USBMux.openSocket()
                defer { Darwin.close(fd) }
                try USBMux.sendListen(fd: fd)
                lastError = ""
                while true {
                    let packet = try USBMux.readPacket(fd: fd)
                    handle(packet)
                }
            } catch {
                onReset?()
                let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                if text != lastError {
                    onLog?("usbmuxd: \(text)")
                    lastError = text
                }
            }
            Thread.sleep(forTimeInterval: 2)
        }
    }

    private func handle(_ packet: [String: Any]) {
        guard let type = packet["MessageType"] as? String else { return }
        switch type {
        case "Attached":
            guard let id = packet["DeviceID"] as? Int else { return }
            let properties = packet["Properties"] as? [String: Any] ?? [:]
            let connection = properties["ConnectionType"] as? String ?? "USB"
            guard connection == "USB" else { return } // WLAN-Sync-Geräte ignorieren
            let serial = properties["SerialNumber"] as? String ?? "?"
            onAttach?(USBMuxDevice(id: id, serial: serial))
        case "Detached":
            if let id = packet["DeviceID"] as? Int {
                onDetach?(id)
            }
        case "Result":
            if let number = packet["Number"] as? Int, number != 0 {
                onLog?("usbmuxd Listen-Fehler (Code \(number))")
            }
        default:
            break
        }
    }
}

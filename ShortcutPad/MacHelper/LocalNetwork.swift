import Foundation
import Darwin

enum LocalNetwork {
    /// IPv4-Adressen der WLAN-/Ethernet-Schnittstellen (en0, en1 …) ohne Link-Local-Adressen.
    /// Sortiert nach Wahrscheinlichkeit, vom iPad erreichbar zu sein: 192.168.x.x zuerst, dann 10.x.x.x, dann 172.16–31.x.x
    /// (dort liegen oft virtuelle Netze wie Docker), alles andere zuletzt.
    static func ipv4Addresses() -> [String] {
        let found = rawIPv4Addresses()
        return found.enumerated().sorted { left, right in
            let a = rank(left.element)
            let b = rank(right.element)
            return a != b ? a < b : left.offset < right.offset
        }.map { $0.element }
    }

    private static func rank(_ address: String) -> Int {
        if address.hasPrefix("192.168.") { return 0 }
        if address.hasPrefix("10.") { return 1 }
        let parts = address.split(separator: ".")
        if parts.count == 4, parts[0] == "172", let second = Int(parts[1]), (16...31).contains(second) { return 2 }
        return 3
    }

    private static func rawIPv4Addresses() -> [String] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [] }
        defer { freeifaddrs(list) }

        var result = [String]()
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let interface = cursor {
            defer { cursor = interface.pointee.ifa_next }

            guard let address = interface.pointee.ifa_addr else { continue }
            let flags = Int32(interface.pointee.ifa_flags)
            guard address.pointee.sa_family == UInt8(AF_INET),
                  (flags & IFF_UP) != 0,
                  (flags & IFF_LOOPBACK) == 0
            else { continue }

            let name = String(cString: interface.pointee.ifa_name)
            guard name.hasPrefix("en") else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let length = socklen_t(address.pointee.sa_len)
            guard getnameinfo(address, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let text = String(cString: host)
            if !text.hasPrefix("169.254.") && !result.contains(text) {
                result.append(text)
            }
        }
        return result
    }
}

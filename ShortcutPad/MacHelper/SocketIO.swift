import Foundation
import Darwin

/// Schreibt Bytes vollständig auf einen Dateideskriptor (blockierend). Vom Webserver benutzt.
enum FDIO {
    struct WriteError: Error {
        let code: Int32
    }

    static func writeAll(fd: Int32, bytes: [UInt8]) throws {
        var offset = 0
        while offset < bytes.count {
            let written = bytes.withUnsafeBytes { raw -> Int in
                Darwin.write(fd, raw.baseAddress! + offset, bytes.count - offset)
            }
            if written > 0 {
                offset += written
            } else if written < 0 && errno == EINTR {
                continue
            } else {
                throw WriteError(code: errno)
            }
        }
    }
}

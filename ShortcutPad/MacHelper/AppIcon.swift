import AppKit

/// Zeichnet das Symbol der Web-App für den Home-Bildschirm: ein Raster aus bunten Kacheln auf dunklem Grund.
/// iOS rundet die Ecken selbst ab, deshalb wird das Quadrat randlos gefüllt.
enum AppIcon {
    private static let lock = NSLock()
    private static var cache = [Int: Data]()

    /// PNG-Daten in der gewünschten Kantenlänge (Pixel). Darf von beliebigen Threads aufgerufen werden.
    static func pngData(size: Int) -> Data? {
        lock.lock()
        let cached = cache[size]
        lock.unlock()
        if let cached = cached { return cached }

        let data: Data?
        if Thread.isMainThread {
            data = render(size: size)
        } else {
            data = DispatchQueue.main.sync { render(size: size) }
        }
        if let data = data {
            lock.lock()
            cache[size] = data
            lock.unlock()
        }
        return data
    }

    private static func render(size: Int) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context

        let full = CGFloat(size)
        fill(0x0E0F12).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: full, height: full)).fill()

        let margin = full * 0.17
        let gap = full * 0.055
        let tile = (full - 2 * margin - 2 * gap) / 3
        let palette: [PadColor] = [.blau, .indigo, .orange, .rot, .gruen, .tuerkis, .pink, .grau, .blau]
        for index in 0..<9 {
            let column = CGFloat(index % 3)
            let row = CGFloat(index / 3)
            let x = margin + column * (tile + gap)
            let y = full - margin - tile - row * (tile + gap)
            fill(palette[index].hex).setFill()
            NSBezierPath(
                roundedRect: NSRect(x: x, y: y, width: tile, height: tile),
                xRadius: tile * 0.2,
                yRadius: tile * 0.2
            ).fill()
        }

        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    private static func fill(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

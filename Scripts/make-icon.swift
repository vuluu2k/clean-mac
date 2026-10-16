import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: 1024, height: 1024))
        image.lockFocus()
        let rect = NSRect(x: 60, y: 60, width: 904, height: 904)
        NSColor(calibratedRed: 0.06, green: 0.15, blue: 0.15, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 210, yRadius: 210).fill()
        let config = NSImage.SymbolConfiguration(pointSize: 470, weight: .light)
        if let symbol = NSImage(systemSymbolName: "externaldrive.fill.badge.checkmark", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            let tinted = NSImage(size: symbol.size)
            tinted.lockFocus()
            symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
            NSColor(calibratedRed: 0.39, green: 0.91, blue: 0.72, alpha: 1).setFill()
            NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
            tinted.unlockFocus()
            let ratio = symbol.size.height / symbol.size.width
            tinted.draw(in: NSRect(x: 245, y: 512 - 267 * ratio, width: 534, height: 534 * ratio))
        }
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let source = NSBitmapImageRep(data: tiff),
              let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot render icon") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        source.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode icon") }
        let suffix = scale == 2 ? "@2x" : ""
        try png.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}

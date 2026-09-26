import AppKit

/// Vector source for the packaged macOS app icon. Run scripts/generate-icons.sh to export it.
enum LDCIconGenerator {
    static func bitmap(pixels: Int) -> NSBitmapImageRep {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        bitmap.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current?.shouldAntialias = true
        let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
        (transform as NSAffineTransform).concat()
        draw(detailed: pixels >= 64)
        return bitmap
    }

    private static func draw(detailed: Bool) {
        func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
            NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
        }
        func rounded(_ rect: NSRect, radius: CGFloat, fill: NSColor) {
            fill.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        }
        func line(_ points: [NSPoint], width: CGFloat, stroke: NSColor) {
            let path = NSBezierPath()
            path.move(to: points[0])
            for point in points.dropFirst() { path.line(to: point) }
            path.lineWidth = width
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            stroke.setStroke()
            path.stroke()
        }
        let navy = color(0.025, 0.095, 0.16)
        let mint = color(0.34, 1.0, 0.78)
        let white = color(0.92, 0.99, 1.0)
        let tile = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 190, yRadius: 190)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
        shadow.shadowBlurRadius = 24
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        shadow.set()
        navy.setFill()
        tile.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGradient(starting: color(0.08, 0.25, 0.43), ending: color(0.015, 0.43, 0.44))!
            .draw(in: tile, angle: -75)
        if detailed {
            white.withAlphaComponent(0.16).setStroke()
            tile.lineWidth = 3
            tile.stroke()
        }

        // One terminal controlling three LAN devices, with a shared network bus.
        let wire = white.withAlphaComponent(0.94)
        line([NSPoint(x: 512, y: 450), NSPoint(x: 512, y: 365)], width: 28, stroke: wire)
        line([NSPoint(x: 272, y: 285), NSPoint(x: 272, y: 365), NSPoint(x: 752, y: 365), NSPoint(x: 752, y: 285)], width: 28, stroke: wire)
        line([NSPoint(x: 512, y: 365), NSPoint(x: 512, y: 285)], width: 28, stroke: wire)

        // Bright chassis and dark display retain the terminal silhouette at small sizes.
        rounded(NSRect(x: 224, y: 440, width: 576, height: 350), radius: 62, fill: white)
        rounded(NSRect(x: 252, y: 468, width: 520, height: 294), radius: 38, fill: navy)
        if detailed {
            line([NSPoint(x: 284, y: 708), NSPoint(x: 740, y: 708)], width: 3, stroke: white.withAlphaComponent(0.13))
            for x in [CGFloat(291), 319, 347] {
                color(0.33, 0.62, 0.68).setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: 725, width: 12, height: 12)).fill()
            }
        }
        line([NSPoint(x: 350, y: 650), NSPoint(x: 426, y: 595), NSPoint(x: 350, y: 540)], width: 36, stroke: mint)
        line([NSPoint(x: 484, y: 540), NSPoint(x: 612, y: 540)], width: 36, stroke: mint)

        for center in [CGFloat(272), 512, 752] {
            rounded(NSRect(x: center - 72, y: 200, width: 144, height: 112), radius: 30, fill: white)
            if detailed {
                rounded(NSRect(x: center - 49, y: 236, width: 98, height: 53), radius: 12, fill: navy)
                mint.setFill()
                NSBezierPath(ovalIn: NSRect(x: center - 7, y: 213, width: 14, height: 14)).fill()
            } else {
                rounded(NSRect(x: center - 38, y: 230, width: 76, height: 52), radius: 10, fill: navy)
            }
        }
    }
}

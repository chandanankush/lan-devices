import Foundation
import AppKit

enum IconGenerator {
    static func makeIcon(size: CGFloat = 1024) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high
        NSGraphicsContext.current?.shouldAntialias = true

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let radius = size * 0.2

        // Background rounded rectangle with gradient
        let clipPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        clipPath.addClip()

        let top = NSColor(calibratedRed: 0.10, green: 0.20, blue: 0.45, alpha: 1.0)
        let bottom = NSColor(calibratedRed: 0.05, green: 0.70, blue: 0.65, alpha: 1.0)
        let gradient = NSGradient(starting: top, ending: bottom)
        gradient?.draw(in: rect, angle: 90)

        // Subtle inner border
        let borderPath = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.01, dy: size * 0.01), xRadius: radius - size * 0.01, yRadius: radius - size * 0.01)
        NSColor.white.withAlphaComponent(0.12).setStroke()
        borderPath.lineWidth = size * 0.02
        borderPath.stroke()

        // Terminal-like prompt: chevron '>' and underscore '_'
        // Chevron path
        let chevron = NSBezierPath()
        chevron.move(to: NSPoint(x: size * 0.32, y: size * 0.30))
        chevron.line(to: NSPoint(x: size * 0.68, y: size * 0.50))
        chevron.line(to: NSPoint(x: size * 0.32, y: size * 0.70))
        chevron.lineWidth = size * 0.10
        chevron.lineCapStyle = .round
        chevron.lineJoinStyle = .round
        NSColor.white.setStroke()
        chevron.stroke()

        // Underscore block
        let underscoreRect = NSRect(x: size * 0.70, y: size * 0.28, width: size * 0.18, height: size * 0.08)
        let underscore = NSBezierPath(roundedRect: underscoreRect, xRadius: size * 0.04, yRadius: size * 0.04)
        NSColor.white.setFill()
        underscore.fill()

        // Optional glossy top highlight
        let highlightRect = NSRect(x: 0, y: size * 0.55, width: size, height: size * 0.45)
        let highlightGradient = NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0.0)])
        highlightGradient?.draw(in: highlightRect, angle: -90)

        return image
    }
}

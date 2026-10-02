import AppKit

/// Menu bar cup: outlined when idle, filled with three wisps of steam while sleep is disabled.
/// Both states share one canvas so the icon doesn't shift when it flips.
enum CupGlyph {
    static let size = NSSize(width: 22, height: 22)
    /// How far the steam reaches above the cup's frame, in points.
    private static let steamRise: CGFloat = 4.1
    private static let idleDrop: CGFloat = 1.5

    static func image(steaming: Bool) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        let cup = NSImage(systemSymbolName: steaming ? "cup.and.saucer.fill" : "cup.and.saucer", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)

        let image = NSImage(size: size, flipped: false) { bounds in
            guard let cup else { return true }
            // Cup and steam are centred as one group, so the steaming cup drops by half the steam's height.
            // The idle cup's symbol carries empty space above the rim; the extra drop centres it optically.
            let groupHeight = cup.size.height + (steaming ? steamRise : 0)
            let y = (bounds.height - groupHeight) / 2 - (steaming ? 0 : idleDrop)
            let cupFrame = NSRect(x: (bounds.width - cup.size.width) / 2,
                                  y: (y * 2).rounded() / 2,
                                  width: cup.size.width, height: cup.size.height)
            cup.draw(in: cupFrame)
            if steaming {
                NSColor.black.setFill()
                // The mug body sits left of the saucer's centre because of the handle.
                let x = cupFrame.midX - cupFrame.width * 0.04
                // Wisps start inside the cup's opening so they rise straight out of it.
                // The middle wisp starts higher and rises further than the side ones.
                for (dx, lift, height) in [(-2.0, 0.0, 5.6), (0.0, 0.5, 7.2), (2.0, 0.0, 5.6)] as [(CGFloat, CGFloat, CGFloat)] {
                    let base = NSPoint(x: x + dx, y: cupFrame.maxY - 3.6 + lift)
                    petal(from: base, height: height, sway: 0.9, width: 0.9).fill()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// An S-shaped leaf: a bent stroke that tapers to a point at both ends.
    static func petal(from base: NSPoint, height: CGFloat, sway: CGFloat, width: CGFloat) -> NSBezierPath {
        let top = NSPoint(x: base.x, y: base.y + height)
        let c1 = NSPoint(x: base.x + sway, y: base.y + height * 0.33)
        let c2 = NSPoint(x: base.x - sway, y: base.y + height * 0.67)
        let path = NSBezierPath()
        path.move(to: base)
        path.curve(to: top, controlPoint1: NSPoint(x: c1.x - width, y: c1.y), controlPoint2: NSPoint(x: c2.x - width, y: c2.y))
        path.curve(to: base, controlPoint1: NSPoint(x: c2.x + width, y: c2.y), controlPoint2: NSPoint(x: c1.x + width, y: c1.y))
        path.close()
        return path
    }
}

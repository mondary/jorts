import AppKit
import SwiftUI

extension NoteTheme {
    var backgroundHex: Int {
        switch self {
        case .blueberry: 0xD8ECFF
        case .mint: 0xDFF8EF
        case .lime: 0xE9F8D8
        case .banana: 0xFFF3B0
        case .orange: 0xFFE0C2
        case .strawberry: 0xFFD6D6
        case .bubblegum: 0xFAD7F2
        case .grape: 0xE6D9FF
        case .cocoa: 0xE7D8C8
        case .slate: 0xE1E5EA
        case .latte: 0xF4E3C1
        case .hotPink: 0xFF6B9D
        case .electricBlue: 0x4FC3F7
        case .neonGreen: 0x69F0AE
        case .crimson: 0xFF5252
        case .sunshine: 0xFFEB3B
        case .violet: 0xB388FF
        case .tangerine: 0xFF9800
        }
    }

    var foregroundHex: Int {
        switch self {
        case .blueberry: 0x0E3A66
        case .mint: 0x0B4A3A
        case .lime: 0x314A08
        case .banana: 0x5A4300
        case .orange: 0x673208
        case .strawberry: 0x6D1010
        case .bubblegum: 0x6A1857
        case .grape: 0x3B176F
        case .cocoa: 0x4D3424
        case .slate: 0x25313D
        case .latte: 0x5C4630
        case .hotPink: 0x4A0A2A
        case .electricBlue: 0x0A2E4A
        case .neonGreen: 0x1B4A0A
        case .crimson: 0x4A0A0A
        case .sunshine: 0x4A3A00
        case .violet: 0x2A0A4A
        case .tangerine: 0x4A2A00
        }
    }

    var accentHex: Int {
        switch self {
        case .blueberry: 0x3689E6
        case .mint: 0x28BCA3
        case .lime: 0x8BC34A
        case .banana: 0xF9C440
        case .orange: 0xFF8C1A
        case .strawberry: 0xED5353
        case .bubblegum: 0xE753B9
        case .grape: 0x9B6BE8
        case .cocoa: 0x8B5E3C
        case .slate: 0x667885
        case .latte: 0xC8954A
        case .hotPink: 0xE91E63
        case .electricBlue: 0x00BCD4
        case .neonGreen: 0x00E676
        case .crimson: 0xD50000
        case .sunshine: 0xFFC107
        case .violet: 0x7C4DFF
        case .tangerine: 0xFF5722
        }
    }

    var backgroundColor: Color {
        Color(hex: backgroundHex)
    }

    var foregroundColor: Color {
        Color(hex: foregroundHex)
    }

    var accentColor: Color {
        Color(hex: accentHex)
    }

    var backgroundNSColor: NSColor {
        NSColor(hex: backgroundHex)
    }

    var foregroundNSColor: NSColor {
        NSColor(hex: foregroundHex)
    }

    var accentNSColor: NSColor {
        NSColor(hex: accentHex)
    }

    var menuSwatchImage: NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)

        image.lockFocus()

        let bounds = NSRect(origin: .zero, size: size)
        let swatchRect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(ovalIn: swatchRect)

        backgroundNSColor.setFill()
        path.fill()

        accentNSColor.withAlphaComponent(0.75).setStroke()
        path.lineWidth = 1
        path.stroke()

        image.unlockFocus()
        image.isTemplate = false

        return image
    }
}

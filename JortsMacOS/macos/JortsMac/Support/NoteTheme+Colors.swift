import AppKit
import SwiftUI

extension NoteTheme {
    var backgroundHex: Int {
        switch self {
        // Original colors (0-17)
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

        // 100-color palette - Row 1: Lightest (18-27)
        case .paleBlue1: 0xE6F3FF
        case .paleBlue2: 0xF0E6FF
        case .paleBlue3: 0xFFE6F8
        case .paleBlue4: 0xFFE6E6
        case .paleBlue5: 0xFFE6F0
        case .paleBlue6: 0xFFF0E6
        case .paleBlue7: 0xFFFFE6
        case .paleBlue8: 0xF6FFE6
        case .paleBlue9: 0xE6FFF0
        case .paleBlue10: 0xE6FFFF

        // Row 2: Light (28-37)
        case .lightBlue1: 0xCCE5FF
        case .lightBlue2: 0xDDCCFF
        case .lightBlue3: 0xFFCCF0
        case .lightBlue4: 0xFFCCCC
        case .lightBlue5: 0xFFCCDD
        case .lightBlue6: 0xFFDDCC
        case .lightBlue7: 0xFFFFCC
        case .lightBlue8: 0xEDFFCC
        case .lightBlue9: 0xCCFFDD
        case .lightBlue10: 0xCCFFFF

        // Row 3: Medium-Light (38-47)
        case .blue1: 0x99CCFF
        case .blue2: 0xBB99FF
        case .blue3: 0xFF99E5
        case .blue4: 0xFF9999
        case .blue5: 0xFF99BB
        case .blue6: 0xFFBB99
        case .blue7: 0xFFFF99
        case .blue8: 0xE5FF99
        case .blue9: 0x99FFCC
        case .blue10: 0x99FFFF

        // Row 4: Medium (48-57)
        case .deepBlue1: 0x66B2FF
        case .deepBlue2: 0x9966FF
        case .deepBlue3: 0xFF66DB
        case .deepBlue4: 0xFF6666
        case .deepBlue5: 0xFF6699
        case .deepBlue6: 0xFF9966
        case .deepBlue7: 0xFFFF66
        case .deepBlue8: 0xDBFF66
        case .deepBlue9: 0x66FFB2
        case .deepBlue10: 0x66FFFF

        // Row 5: Medium-Dark (58-67)
        case .navy1: 0x3399FF
        case .navy2: 0x7733FF
        case .navy3: 0xFF33D1
        case .navy4: 0xFF3333
        case .navy5: 0xFF3377
        case .navy6: 0xFF7733
        case .navy7: 0xFFFF33
        case .navy8: 0xD1FF33
        case .navy9: 0x33FF99
        case .navy10: 0x33FFFF

        // Row 6: Dark (68-77)
        case .darkNavy1: 0x0080FF
        case .darkNavy2: 0x5500FF
        case .darkNavy3: 0xFF00C7
        case .darkNavy4: 0xFF0000
        case .darkNavy5: 0xFF0055
        case .darkNavy6: 0xFF5500
        case .darkNavy7: 0xFFFF00
        case .darkNavy8: 0xC7FF00
        case .darkNavy9: 0x00FF88
        case .darkNavy10: 0x00FFFF

        // Row 7: Darker (78-87)
        case .deepPurple1: 0x0066CC
        case .deepPurple2: 0x4400CC
        case .deepPurple3: 0xCC00BD
        case .deepPurple4: 0xCC0000
        case .deepPurple5: 0xCC0044
        case .deepPurple6: 0xCC4400
        case .deepPurple7: 0xCCCC00
        case .deepPurple8: 0xBDCC00
        case .deepPurple9: 0x00CC77
        case .deepPurple10: 0x00CCCC

        // Row 8: Even Darker (88-97)
        case .darkPurple1: 0x004D99
        case .darkPurple2: 0x330099
        case .darkPurple3: 0x990099
        case .darkPurple4: 0x990000
        case .darkPurple5: 0x990033
        case .darkPurple6: 0x993300
        case .darkPurple7: 0x999900
        case .darkPurple8: 0x7F9900
        case .darkPurple9: 0x00995C
        case .darkPurple10: 0x009999

        // Row 9: Very Dark (98-107)
        case .darkestBlue1: 0x003366
        case .darkestBlue2: 0x220066
        case .darkestBlue3: 0x660066
        case .darkestBlue4: 0x660000
        case .darkestBlue5: 0x660022
        case .darkestBlue6: 0x662200
        case .darkestBlue7: 0x666600
        case .darkestBlue8: 0x556600
        case .darkestBlue9: 0x006644
        case .darkestBlue10: 0x006666

        // Row 10: Darkest (108-117)
        case .deepestBlue1: 0x001A33
        case .deepestBlue2: 0x110033
        case .deepestBlue3: 0x330033
        case .deepestBlue4: 0x330000
        case .deepestBlue5: 0x330011
        case .deepestBlue6: 0x331100
        case .deepestBlue7: 0x333300
        case .deepestBlue8: 0x2A3300
        case .deepestBlue9: 0x003322
        case .deepestBlue10: 0x003333
        }
    }

    var foregroundHex: Int {
        switch self {
        // Original colors (0-17)
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

        // 100-color palette - Row 1: Lightest (18-27)
        case .paleBlue1: 0x1A2E44
        case .paleBlue2: 0x2E1A44
        case .paleBlue3: 0x441A38
        case .paleBlue4: 0x441A1A
        case .paleBlue5: 0x441A2E
        case .paleBlue6: 0x442E1A
        case .paleBlue7: 0x44441A
        case .paleBlue8: 0x38441A
        case .paleBlue9: 0x1A442E
        case .paleBlue10: 0x1A4444

        // Row 2: Light (28-37)
        case .lightBlue1: 0x154266
        case .lightBlue2: 0x331566
        case .lightBlue3: 0x66154A
        case .lightBlue4: 0x661515
        case .lightBlue5: 0x661533
        case .lightBlue6: 0x663315
        case .lightBlue7: 0x666615
        case .lightBlue8: 0x4A6615
        case .lightBlue9: 0x156642
        case .lightBlue10: 0x156666

        // Row 3: Medium-Light (38-47)
        case .blue1: 0x1A3D5C
        case .blue2: 0x3D1A5C
        case .blue3: 0x5C1A4D
        case .blue4: 0x5C1A1A
        case .blue5: 0x5C1A3D
        case .blue6: 0x5C3D1A
        case .blue7: 0x5C5C1A
        case .blue8: 0x4D5C1A
        case .blue9: 0x1A5C4D
        case .blue10: 0x1A5C5C

        // Row 4: Medium (48-57)
        case .deepBlue1: 0x154A70
        case .deepBlue2: 0x3A1570
        case .deepBlue3: 0x70155C
        case .deepBlue4: 0x701515
        case .deepBlue5: 0x70153A
        case .deepBlue6: 0x703A15
        case .deepBlue7: 0x707015
        case .deepBlue8: 0x5C7015
        case .deepBlue9: 0x157055
        case .deepBlue10: 0x157070

        // Row 5: Medium-Dark (58-67)
        case .navy1: 0x0F2E4D
        case .navy2: 0x250F4D
        case .navy3: 0x4D0F40
        case .navy4: 0x4D0F0F
        case .navy5: 0x4D0F25
        case .navy6: 0x4D250F
        case .navy7: 0x4D4D0F
        case .navy8: 0x404D0F
        case .navy9: 0x0F4D3A
        case .navy10: 0x0F4D4D

        // Row 6: Dark (68-77)
        case .darkNavy1: 0x002244
        case .darkNavy2: 0x150044
        case .darkNavy3: 0x44003A
        case .darkNavy4: 0x440000
        case .darkNavy5: 0x440015
        case .darkNavy6: 0x441500
        case .darkNavy7: 0x444400
        case .darkNavy8: 0x3A4400
        case .darkNavy9: 0x004429
        case .darkNavy10: 0x004444

        // Row 7: Darker (78-87)
        case .deepPurple1: 0x001A33
        case .deepPurple2: 0x110033
        case .deepPurple3: 0x33002E
        case .deepPurple4: 0x330000
        case .deepPurple5: 0x330011
        case .deepPurple6: 0x331100
        case .deepPurple7: 0x333300
        case .deepPurple8: 0x2E3300
        case .deepPurple9: 0x00331E
        case .deepPurple10: 0x003333

        // Row 8: Even Darker (88-97)
        case .darkPurple1: 0x001122
        case .darkPurple2: 0x0A0022
        case .darkPurple3: 0x220022
        case .darkPurple4: 0x220000
        case .darkPurple5: 0x22000A
        case .darkPurple6: 0x220A00
        case .darkPurple7: 0x222200
        case .darkPurple8: 0x1C2200
        case .darkPurple9: 0x002215
        case .darkPurple10: 0x002222

        // Row 9: Very Dark (98-107)
        case .darkestBlue1: 0x000D1A
        case .darkestBlue2: 0x06001A
        case .darkestBlue3: 0x1A001A
        case .darkestBlue4: 0x1A0000
        case .darkestBlue5: 0x1A0006
        case .darkestBlue6: 0x1A0600
        case .darkestBlue7: 0x1A1A00
        case .darkestBlue8: 0x151A00
        case .darkestBlue9: 0x001A0D
        case .darkestBlue10: 0x001A1A

        // Row 10: Darkest (108-117)
        case .deepestBlue1: 0x000611
        case .deepestBlue2: 0x030011
        case .deepestBlue3: 0x110011
        case .deepestBlue4: 0x110000
        case .deepestBlue5: 0x110003
        case .deepestBlue6: 0x110300
        case .deepestBlue7: 0x111100
        case .deepestBlue8: 0x0D1100
        case .deepestBlue9: 0x001109
        case .deepestBlue10: 0x001111
        }
    }

    var accentHex: Int {
        switch self {
        // Original colors (0-17)
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

        // 100-color palette - Row 1: Lightest (18-27)
        case .paleBlue1: 0xB3D9FF
        case .paleBlue2: 0xD9B3FF
        case .paleBlue3: 0xFFB3EA
        case .paleBlue4: 0xFFB3B3
        case .paleBlue5: 0xFFB3D9
        case .paleBlue6: 0xFFD9B3
        case .paleBlue7: 0xFFFFB3
        case .paleBlue8: 0xEAFFB3
        case .paleBlue9: 0xB3FFE5
        case .paleBlue10: 0xB3FFFF

        // Row 2: Light (28-37)
        case .lightBlue1: 0x80C0FF
        case .lightBlue2: 0xB380FF
        case .lightBlue3: 0xFF80E0
        case .lightBlue4: 0xFF8080
        case .lightBlue5: 0xFF80B3
        case .lightBlue6: 0xFFB380
        case .lightBlue7: 0xFFFF80
        case .lightBlue8: 0xE0FF80
        case .lightBlue9: 0x80FFC0
        case .lightBlue10: 0x80FFFF

        // Row 3: Medium-Light (38-47)
        case .blue1: 0x4DA6FF
        case .blue2: 0x994DFF
        case .blue3: 0xFF4DCC
        case .blue4: 0xFF4D4D
        case .blue5: 0xFF4D99
        case .blue6: 0xFF994D
        case .blue7: 0xFFFF4D
        case .blue8: 0xCCFF4D
        case .blue9: 0x4DFFA6
        case .blue10: 0x4DFFFF

        // Row 4: Medium (48-57)
        case .deepBlue1: 0x1A8CFF
        case .deepBlue2: 0x661AFF
        case .deepBlue3: 0xFF1AB8
        case .deepBlue4: 0xFF1A1A
        case .deepBlue5: 0xFF1A66
        case .deepBlue6: 0xFF661A
        case .deepBlue7: 0xFFFF1A
        case .deepBlue8: 0xB8FF1A
        case .deepBlue9: 0x1AFF8C
        case .deepBlue10: 0x1AFFFF

        // Row 5: Medium-Dark (58-67)
        case .navy1: 0x0070E6
        case .navy2: 0x4D00E6
        case .navy3: 0xE600A3
        case .navy4: 0xE60000
        case .navy5: 0xE6004D
        case .navy6: 0xE64D00
        case .navy7: 0xE6E600
        case .navy8: 0xA3E600
        case .navy9: 0x00E670
        case .navy10: 0x00E6E6

        // Row 6: Dark (68-77)
        case .darkNavy1: 0x0055B3
        case .darkNavy2: 0x3B00B3
        case .darkNavy3: 0xB3007D
        case .darkNavy4: 0xB30000
        case .darkNavy5: 0xB3003B
        case .darkNavy6: 0xB33B00
        case .darkNavy7: 0xB3B300
        case .darkNavy8: 0x7DB300
        case .darkNavy9: 0x00B355
        case .darkNavy10: 0x00B3B3

        // Row 7: Darker (78-87)
        case .deepPurple1: 0x004080
        case .deepPurple2: 0x280080
        case .deepPurple3: 0x800058
        case .deepPurple4: 0x800000
        case .deepPurple5: 0x800028
        case .deepPurple6: 0x802800
        case .deepPurple7: 0x808000
        case .deepPurple8: 0x588000
        case .deepPurple9: 0x008040
        case .deepPurple10: 0x008080

        // Row 8: Even Darker (88-97)
        case .darkPurple1: 0x002B4D
        case .darkPurple2: 0x1A004D
        case .darkPurple3: 0x4D003B
        case .darkPurple4: 0x4D0000
        case .darkPurple5: 0x4D001A
        case .darkPurple6: 0x4D1A00
        case .darkPurple7: 0x4D4D00
        case .darkPurple8: 0x3B4D00
        case .darkPurple9: 0x004D2B
        case .darkPurple10: 0x004D4D

        // Row 9: Very Dark (98-107)
        case .darkestBlue1: 0x001526
        case .darkestBlue2: 0x0D0026
        case .darkestBlue3: 0x26001F
        case .darkestBlue4: 0x260000
        case .darkestBlue5: 0x26000D
        case .darkestBlue6: 0x260D00
        case .darkestBlue7: 0x262600
        case .darkestBlue8: 0x1F2600
        case .darkestBlue9: 0x002615
        case .darkestBlue10: 0x002626

        // Row 10: Darkest (108-117)
        case .deepestBlue1: 0x00080F
        case .deepestBlue2: 0x05000F
        case .deepestBlue3: 0x0F000D
        case .deepestBlue4: 0x0F0000
        case .deepestBlue5: 0x0F0005
        case .deepestBlue6: 0x0F0500
        case .deepestBlue7: 0x0F0F00
        case .deepestBlue8: 0x0D0F00
        case .deepestBlue9: 0x000F08
        case .deepestBlue10: 0x000F0F
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

    // Calcule automatiquement la couleur du texte (blanc sur fond sombre, noir sur fond clair)
    var autoTextColor: NSColor {
        let luminance = calculateLuminance(hex: backgroundHex)
        return luminance > 0.5 ? NSColor(hex: 0x000000) : NSColor(hex: 0xFFFFFF)
    }

    var autoTextColorColor: Color {
        Color(autoTextColor)
    }

    private func calculateLuminance(hex: Int) -> Double {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0

        let rLinear = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let gLinear = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let bLinear = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)

        return 0.2126 * rLinear + 0.7152 * gLinear + 0.0722 * bLinear
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

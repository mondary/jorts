import AppKit
import SwiftUI

extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

extension Color {
    init(hex: Int, alpha: CGFloat = 1.0) {
        self.init(nsColor: NSColor(hex: hex, alpha: alpha))
    }
}

import AppKit
import CoreText
import Foundation

enum FontRegistrar {
    private static let redactedFontNames = [
        "Redacted Script",
        "RedactedScript-Regular",
        "RedactedScript"
    ]

    static func registerBundledFonts() {
        guard let fontURL = Bundle.module.url(
            forResource: "RedactedScript-Regular",
            withExtension: "ttf"
        ) else {
            NSLog("JortsMac: bundled Redacted Script font not found")
            return
        }

        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
    }

    static func redactedFont(size: CGFloat) -> NSFont? {
        for name in redactedFontNames {
            if let font = NSFont(name: name, size: size) {
                return font
            }
        }

        return nil
    }
}

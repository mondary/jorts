import Foundation
import AppKit

enum FontFamily: String, CaseIterable, Codable, Identifiable {
    case system = "System"
    case rounded = "SF Pro Rounded"
    case mono = "SF Mono"
    case monoLight = "SF Mono Light"
    case helvetica = "Helvetica"
    case helveticaBold = "Helvetica Bold"
    case menlo = "Menlo"
    case courier = "Courier New"
    case georgia = "Georgia"
    case palatino = "Palatino"
    case fuente = "Futura"
    case rockwell = "Rockwell"
    case optima = "Optima"
    case didot = "Didot"
    case bodoni = "Bodoni 72"

    // Nerds Fonts (si disponibles)
    case jetbrainsMono = "JetBrainsMono Nerd Font"
    case firaCode = "FiraCode Nerd Font"
    case hack = "Hack Nerd Font"
    case sourceCodePro = "SauceCodePro Nerd Font"
    case monoid = "Monoid Nerd Font"
    case meslo = "MesloLG Nerd Font"
    case cascadia = "CascadiaCode Nerd Font"

    var id: String { rawValue }

    var displayName: String {
        rawValue
    }

    var isAvailable: Bool {
        if self == .system {
            return true
        }
        return NSFont(name: rawValue, size: 12) != nil
    }

    var fontName: String {
        switch self {
        case .system: return ".AppleSystemUIFont"
        default: return rawValue
        }
    }

    static var availableFonts: [FontFamily] {
        allCases.filter { $0.isAvailable }
    }

    static var nerdFonts: [FontFamily] {
        [
            .jetbrainsMono,
            .firaCode,
            .hack,
            .sourceCodePro,
            .monoid,
            .meslo,
            .cascadia
        ].filter { $0.isAvailable }
    }

    static var standardFonts: [FontFamily] {
        [
            .system,
            .rounded,
            .mono,
            .monoLight,
            .helvetica,
            .helveticaBold,
            .menlo,
            .courier,
            .georgia,
            .palatino,
            .fuente,
            .rockwell,
            .optima,
            .didot,
            .bodoni
        ]
    }
}

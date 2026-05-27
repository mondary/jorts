import Foundation
import AppKit

enum FontFamily: String, CaseIterable, Codable, Identifiable {
    // System & Standard Fonts
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

    // Nerds Fonts (noms exacts installés sur le système)
    case jetbrainsMono = "JetBrains Mono"
    case jetbrainsMonoNL = "JetBrains Mono NL"
    case hack = "Hack Nerd Font"
    case meslo = "MesloLGSDZ Nerd Font Mono"
    case gohu = "GohuFont 14 Nerd Font Mono"
    case proggyClean = "ProggyClean Nerd Font Mono"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .jetbrainsMono: return "JetBrains Mono"
        case .jetbrainsMonoNL: return "JetBrains Mono NL"
        case .hack: return "Hack Nerd Font"
        case .meslo: return "Meslo LG Nerd Font"
        case .gohu: return "GohuFont Nerd Font"
        case .proggyClean: return "ProggyClean Nerd Font"
        default: return rawValue
        }
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

    var isNerdFont: Bool {
        switch self {
        case .jetbrainsMono, .jetbrainsMonoNL, .hack, .meslo, .gohu, .proggyClean:
            return true
        default:
            return false
        }
    }

    static var availableFonts: [FontFamily] {
        allCases.filter { $0.isAvailable }.sorted { lhs, rhs in
            if lhs.isNerdFont && !rhs.isNerdFont {
                return false
            } else if !lhs.isNerdFont && rhs.isNerdFont {
                return true
            }
            return lhs.displayName < rhs.displayName
        }
    }

    static var nerdFonts: [FontFamily] {
        [
            .jetbrainsMono,
            .jetbrainsMonoNL,
            .hack,
            .meslo,
            .gohu,
            .proggyClean
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

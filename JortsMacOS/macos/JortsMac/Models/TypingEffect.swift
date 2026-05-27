import Foundation

enum TypingEffect: String, CaseIterable, Codable, Identifiable {
    case off
    case confetti
    case doom
    case typewriter
    case wave
    case pop
    case glow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: "Off"
        case .confetti: "Confetti"
        case .doom: "Doom"
        case .typewriter: "Typewriter"
        case .wave: "Wave"
        case .pop: "Pop"
        case .glow: "Glow"
        }
    }
}


import Foundation

enum TypingEffect: String, CaseIterable, Codable, Identifiable {
    case off
    case confetti
    case doom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: "Off"
        case .confetti: "Confetti"
        case .doom: "Doom"
        }
    }
}


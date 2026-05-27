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
        case .off: localizedString("typing_effect_off")
        case .confetti: localizedString("typing_effect_confetti")
        case .doom: localizedString("typing_effect_doom")
        case .typewriter: localizedString("typing_effect_typewriter")
        case .wave: localizedString("typing_effect_wave")
        case .pop: localizedString("typing_effect_pop")
        case .glow: localizedString("typing_effect_glow")
        }
    }
}

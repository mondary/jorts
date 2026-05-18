import Foundation

enum NoteTheme: Int, CaseIterable, Codable, Identifiable {
    case blueberry = 0
    case mint = 1
    case lime = 2
    case banana = 3
    case orange = 4
    case strawberry = 5
    case bubblegum = 6
    case grape = 7
    case cocoa = 8
    case slate = 9
    case latte = 10
    case hotPink = 11
    case electricBlue = 12
    case neonGreen = 13
    case crimson = 14
    case sunshine = 15
    case violet = 16
    case tangerine = 17

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .blueberry: "Blueberry"
        case .mint: "Mint"
        case .lime: "Lime"
        case .banana: "Banana"
        case .orange: "Orange"
        case .strawberry: "Strawberry"
        case .bubblegum: "Bubblegum"
        case .grape: "Grape"
        case .cocoa: "Cocoa"
        case .slate: "Slate"
        case .latte: "Latte"
        case .hotPink: "Hot Pink"
        case .electricBlue: "Electric Blue"
        case .neonGreen: "Neon Green"
        case .crimson: "Crimson"
        case .sunshine: "Sunshine"
        case .violet: "Violet"
        case .tangerine: "Tangerine"
        }
    }

    static func random(excluding skippedTheme: NoteTheme? = nil) -> NoteTheme {
        let choices = allCases.filter { $0 != skippedTheme }
        return choices.randomElement() ?? .blueberry
    }
}

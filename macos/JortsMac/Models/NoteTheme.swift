import Foundation

enum NoteTheme: Int, CaseIterable, Codable, Identifiable {
    // Original colors (0-17)
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

    // 100-color palette (18-117)
    // Row 1 - Light blues
    case paleBlue1 = 18, paleBlue2 = 19, paleBlue3 = 20, paleBlue4 = 21, paleBlue5 = 22
    case paleBlue6 = 23, paleBlue7 = 24, paleBlue8 = 25, paleBlue9 = 26, paleBlue10 = 27
    // Row 2 - Medium blues
    case lightBlue1 = 28, lightBlue2 = 29, lightBlue3 = 30, lightBlue4 = 31, lightBlue5 = 32
    case lightBlue6 = 33, lightBlue7 = 34, lightBlue8 = 35, lightBlue9 = 36, lightBlue10 = 37
    // Row 3 - Blue to purple transition
    case blue1 = 38, blue2 = 39, blue3 = 40, blue4 = 41, blue5 = 42
    case blue6 = 43, blue7 = 44, blue8 = 45, blue9 = 46, blue10 = 47
    // Row 4 - Deep blues
    case deepBlue1 = 48, deepBlue2 = 49, deepBlue3 = 50, deepBlue4 = 51, deepBlue5 = 52
    case deepBlue6 = 53, deepBlue7 = 54, deepBlue8 = 55, deepBlue9 = 56, deepBlue10 = 57
    // Row 5 - Navy to purple
    case navy1 = 58, navy2 = 59, navy3 = 60, navy4 = 61, navy5 = 62
    case navy6 = 63, navy7 = 64, navy8 = 65, navy9 = 66, navy10 = 67
    // Row 6 - Dark navy to dark purple
    case darkNavy1 = 68, darkNavy2 = 69, darkNavy3 = 70, darkNavy4 = 71, darkNavy5 = 72
    case darkNavy6 = 73, darkNavy7 = 74, darkNavy8 = 75, darkNavy9 = 76, darkNavy10 = 77
    // Row 7 - Deep purple to dark red
    case deepPurple1 = 78, deepPurple2 = 79, deepPurple3 = 80, deepPurple4 = 81, deepPurple5 = 82
    case deepPurple6 = 83, deepPurple7 = 84, deepPurple8 = 85, deepPurple9 = 86, deepPurple10 = 87
    // Row 8 - Dark purple to dark red
    case darkPurple1 = 88, darkPurple2 = 89, darkPurple3 = 90, darkPurple4 = 91, darkPurple5 = 92
    case darkPurple6 = 93, darkPurple7 = 94, darkPurple8 = 95, darkPurple9 = 96, darkPurple10 = 97
    // Row 9 - Darkest tones
    case darkestBlue1 = 98, darkestBlue2 = 99, darkestBlue3 = 100, darkestBlue4 = 101, darkestBlue5 = 102
    case darkestBlue6 = 103, darkestBlue7 = 104, darkestBlue8 = 105, darkestBlue9 = 106, darkestBlue10 = 107
    // Row 10 - Deepest tones
    case deepestBlue1 = 108, deepestBlue2 = 109, deepestBlue3 = 110, deepestBlue4 = 111, deepestBlue5 = 112
    case deepestBlue6 = 113, deepestBlue7 = 114, deepestBlue8 = 115, deepestBlue9 = 116, deepestBlue10 = 117

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        // Original colors
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

        // 100-color palette names
        case .paleBlue1: "Pale Azure"
        case .paleBlue2: "Pale Sky"
        case .paleBlue3: "Pale Lilac"
        case .paleBlue4: "Pale Pink"
        case .paleBlue5: "Pale Rose"
        case .paleBlue6: "Pale Coral"
        case .paleBlue7: "Pale Peach"
        case .paleBlue8: "Pale Yellow"
        case .paleBlue9: "Pale Lime"
        case .paleBlue10: "Pale Mint"

        case .lightBlue1: "Light Periwinkle"
        case .lightBlue2: "Light Lavender"
        case .lightBlue3: "Light Orchid"
        case .lightBlue4: "Light Magenta"
        case .lightBlue5: "Light Salmon"
        case .lightBlue6: "Light Amber"
        case .lightBlue7: "Light Gold"
        case .lightBlue8: "Light Citrine"
        case .lightBlue9: "Light Chartreuse"
        case .lightBlue10: "Light Turquoise"

        case .blue1: "Soft Blue"
        case .blue2: "Soft Purple"
        case .blue3: "Soft Violet"
        case .blue4: "Soft Fuchsia"
        case .blue5: "Soft Red"
        case .blue6: "Soft Orange"
        case .blue7: "Soft Yellow"
        case .blue8: "Soft Green"
        case .blue9: "Soft Teal"
        case .blue10: "Soft Cyan"

        case .deepBlue1: "Blue"
        case .deepBlue2: "Purple"
        case .deepBlue3: "Violet"
        case .deepBlue4: "Magenta"
        case .deepBlue5: "Crimson"
        case .deepBlue6: "Orange Red"
        case .deepBlue7: "Gold"
        case .deepBlue8: "Green"
        case .deepBlue9: "Teal"
        case .deepBlue10: "Cerulean"

        case .navy1: "Royal Blue"
        case .navy2: "Indigo"
        case .navy3: "Deep Violet"
        case .navy4: "Deep Pink"
        case .navy5: "Red"
        case .navy6: "Red Orange"
        case .navy7: "Yellow Orange"
        case .navy8: "Yellow Green"
        case .navy9: "Green Teal"
        case .navy10: "Sea Green"

        case .darkNavy1: "Navy"
        case .darkNavy2: "Dark Indigo"
        case .darkNavy3: "Dark Purple"
        case .darkNavy4: "Dark Magenta"
        case .darkNavy5: "Dark Red"
        case .darkNavy6: "Dark Orange"
        case .darkNavy7: "Ochre"
        case .darkNavy8: "Olive"
        case .darkNavy9: "Dark Green"
        case .darkNavy10: "Dark Cyan"

        case .deepPurple1: "Midnight Blue"
        case .deepPurple2: "Deep Indigo"
        case .deepPurple3: "Rebecca Purple"
        case .deepPurple4: "Plum"
        case .deepPurple5: "Firebrick"
        case .deepPurple6: "Burnt Orange"
        case .deepPurple7: "Sienna"
        case .deepPurple8: "Dark Olive"
        case .deepPurple9: "Forest Green"
        case .deepPurple10: "Dark Turquoise"

        case .darkPurple1: "Dark Slate Blue"
        case .darkPurple2: "Dark Violet"
        case .darkPurple3: "Dark Orchid"
        case .darkPurple4: "Maroon"
        case .darkPurple5: "Brown"
        case .darkPurple6: "Dark Bronze"
        case .darkPurple7: "Khaki"
        case .darkPurple8: "Drab"
        case .darkPurple9: "Dark Sea Green"
        case .darkPurple10: "Light Sea Green"

        case .darkestBlue1: "Very Dark Blue"
        case .darkestBlue2: "Very Dark Purple"
        case .darkestBlue3: "Very Dark Violet"
        case .darkestBlue4: "Very Dark Magenta"
        case .darkestBlue5: "Very Dark Red"
        case .darkestBlue6: "Very Dark Orange"
        case .darkestBlue7: "Very Dark Yellow"
        case .darkestBlue8: "Very Dark Green"
        case .darkestBlue9: "Very Dark Teal"
        case .darkestBlue10: "Very Dark Cyan"

        case .deepestBlue1: "Almost Black Blue"
        case .deepestBlue2: "Almost Black Purple"
        case .deepestBlue3: "Almost Black Violet"
        case .deepestBlue4: "Almost Black Magenta"
        case .deepestBlue5: "Almost Black Red"
        case .deepestBlue6: "Almost Black Orange"
        case .deepestBlue7: "Almost Black Yellow"
        case .deepestBlue8: "Almost Black Green"
        case .deepestBlue9: "Almost Black Teal"
        case .deepestBlue10: "Almost Black Cyan"
        }
    }

    static func random(excluding skippedTheme: NoteTheme? = nil) -> NoteTheme {
        let choices = allCases.filter { $0 != skippedTheme }
        return choices.randomElement() ?? .blueberry
    }
}

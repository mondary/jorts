import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case english = "en"
    case french = "fr"
    case italian = "it"
    case german = "de"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .french: "Français"
        case .italian: "Italiano"
        case .german: "Deutsch"
        case .spanish: "Español"
        }
    }

    var localizedName: String {
        switch self {
        case .english: "English"
        case .french: "Français"
        case .italian: "Italiano"
        case .german: "Deutsch"
        case .spanish: "Español"
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

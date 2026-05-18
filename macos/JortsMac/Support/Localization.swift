import Foundation

func localizedString(_ key: String) -> String {
    NSLocalizedString(key, bundle: .main, comment: "")
}

func localizedString(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localizedString(key), arguments: arguments)
}

import Foundation

final class LocalizationController {
    static let shared = LocalizationController()

    private(set) var languageCode: String = "en"
    private var localizedBundle: Bundle = .module

    private init() {}

    func setLanguage(code: String) {
        languageCode = code

        if let path = Bundle.module.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            localizedBundle = bundle
        } else if let path = Bundle.module.path(forResource: "en", ofType: "lproj"),
                  let bundle = Bundle(path: path) {
            localizedBundle = bundle
        } else {
            localizedBundle = .module
        }
    }

    func string(forKey key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }
}

func localizedString(_ key: String) -> String {
    LocalizationController.shared.string(forKey: key)
}

func localizedString(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: localizedString(key), arguments: arguments)
}

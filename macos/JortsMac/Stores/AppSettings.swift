import Foundation

final class AppSettings: ObservableObject {
    private enum Keys {
        static let scribblyModeActive = "scribbly-mode-active"
        static let hideActionBar = "hide-bar"
        static let listItemPrefix = "list-item-start"
    }

    private let defaults: UserDefaults

    @Published var scribblyModeActive: Bool {
        didSet { defaults.set(scribblyModeActive, forKey: Keys.scribblyModeActive) }
    }

    @Published var hideActionBar: Bool {
        didSet { defaults.set(hideActionBar, forKey: Keys.hideActionBar) }
    }

    @Published var listItemPrefix: String {
        didSet { defaults.set(listItemPrefix, forKey: Keys.listItemPrefix) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.scribblyModeActive: false,
            Keys.hideActionBar: false,
            Keys.listItemPrefix: " • "
        ])

        scribblyModeActive = defaults.bool(forKey: Keys.scribblyModeActive)
        hideActionBar = defaults.bool(forKey: Keys.hideActionBar)
        listItemPrefix = defaults.string(forKey: Keys.listItemPrefix) ?? " • "
    }

    func resetListPrefix() {
        listItemPrefix = " • "
    }
}

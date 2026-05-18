import Foundation

final class AppSettings: ObservableObject {
    private enum Keys {
        static let scribblyModeActive = "scribbly-mode-active"
        static let hideActionBar = "hide-bar"
        static let listItemPrefix = "list-item-start"
        static let selectedLanguage = "selected-language"
        static let shortcuts = "keyboard-shortcuts"
        static let storageDirectory = "storage-directory"
        static let randomizeNewNotePosition = "randomize-new-note-position"
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

    @Published var selectedLanguage: AppLanguage {
        didSet { defaults.set(selectedLanguage.rawValue, forKey: Keys.selectedLanguage) }
    }

    @Published private(set) var shortcuts: [ShortcutAction: KeyboardShortcutSetting]

    @Published var storageDirectoryPath: String {
        didSet { defaults.set(storageDirectoryPath, forKey: Keys.storageDirectory) }
    }

    @Published var randomizeNewNotePosition: Bool {
        didSet { defaults.set(randomizeNewNotePosition, forKey: Keys.randomizeNewNotePosition) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.scribblyModeActive: false,
            Keys.hideActionBar: false,
            Keys.listItemPrefix: " • ",
            Keys.selectedLanguage: AppLanguage.english.rawValue,
            Keys.storageDirectory: "",
            Keys.randomizeNewNotePosition: true
        ])

        scribblyModeActive = defaults.bool(forKey: Keys.scribblyModeActive)
        hideActionBar = defaults.bool(forKey: Keys.hideActionBar)
        listItemPrefix = defaults.string(forKey: Keys.listItemPrefix) ?? " • "

        let languageRaw = defaults.string(forKey: Keys.selectedLanguage) ?? AppLanguage.english.rawValue
        selectedLanguage = AppLanguage(rawValue: languageRaw) ?? .english
        shortcuts = Self.loadShortcuts(from: defaults)
        storageDirectoryPath = defaults.string(forKey: Keys.storageDirectory) ?? ""
        randomizeNewNotePosition = defaults.bool(forKey: Keys.randomizeNewNotePosition)
    }

    func resetListPrefix() {
        listItemPrefix = " • "
    }

    func shortcut(for action: ShortcutAction) -> KeyboardShortcutSetting {
        shortcuts[action] ?? action.defaultShortcut
    }

    func setShortcut(_ shortcut: KeyboardShortcutSetting, for action: ShortcutAction) {
        shortcuts[action] = shortcut
        saveShortcuts()
    }

    func resetShortcut(for action: ShortcutAction) {
        shortcuts[action] = action.defaultShortcut
        saveShortcuts()
    }

    private func saveShortcuts() {
        let rawShortcuts = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        guard let data = try? JSONEncoder().encode(rawShortcuts) else {
            return
        }
        defaults.set(data, forKey: Keys.shortcuts)
    }

    private static func loadShortcuts(from defaults: UserDefaults) -> [ShortcutAction: KeyboardShortcutSetting] {
        var shortcuts = Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map { ($0, $0.defaultShortcut) })

        guard let data = defaults.data(forKey: Keys.shortcuts),
              let rawShortcuts = try? JSONDecoder().decode([String: KeyboardShortcutSetting].self, from: data)
        else {
            return shortcuts
        }

        for (rawAction, shortcut) in rawShortcuts {
            guard let action = ShortcutAction(rawValue: rawAction) else { continue }
            shortcuts[action] = shortcut
        }

        return shortcuts
    }

    var storageDirectoryURL: URL? {
        let trimmed = storageDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: trimmed, isDirectory: true)
    }
}

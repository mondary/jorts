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
        static let typingEffect = "typing-effect"
        static let inlineCalculations = "inline-calculations"
        static let inlineBrandIcons = "inline-brand-icons"
        static let clipboardDrawerEdge = "clipboard-drawer-edge"
        static let clipboardMaxItems = "clipboard-max-items"
        static let clipboardMaxAgeDays = "clipboard-max-age-days"
        static let clipboardSourceMode = "clipboard-source-mode"
        static let clipboardSourceList = "clipboard-source-list"
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
        didSet {
            defaults.set(selectedLanguage.rawValue, forKey: Keys.selectedLanguage)
            applyLanguagePreference()
        }
    }

    @Published private(set) var shortcuts: [ShortcutAction: KeyboardShortcutSetting]

    @Published var storageDirectoryPath: String {
        didSet { defaults.set(storageDirectoryPath, forKey: Keys.storageDirectory) }
    }

    @Published var randomizeNewNotePosition: Bool {
        didSet { defaults.set(randomizeNewNotePosition, forKey: Keys.randomizeNewNotePosition) }
    }

    @Published var typingEffect: TypingEffect {
        didSet { defaults.set(typingEffect.rawValue, forKey: Keys.typingEffect) }
    }

    @Published var inlineCalculations: Bool {
        didSet { defaults.set(inlineCalculations, forKey: Keys.inlineCalculations) }
    }

    @Published var inlineBrandIcons: Bool {
        didSet { defaults.set(inlineBrandIcons, forKey: Keys.inlineBrandIcons) }
    }

    @Published var clipboardDrawerEdge: ClipboardDrawerEdge {
        didSet { defaults.set(clipboardDrawerEdge.rawValue, forKey: Keys.clipboardDrawerEdge) }
    }

    @Published var clipboardMaxItems: Int {
        didSet { defaults.set(clipboardMaxItems, forKey: Keys.clipboardMaxItems) }
    }

    @Published var clipboardMaxAgeDays: Int {
        didSet { defaults.set(clipboardMaxAgeDays, forKey: Keys.clipboardMaxAgeDays) }
    }

    @Published var clipboardSourceMode: ClipboardSourceMode {
        didSet { defaults.set(clipboardSourceMode.rawValue, forKey: Keys.clipboardSourceMode) }
    }

    @Published var clipboardSourceList: [String] {
        didSet {
            if let data = try? JSONEncoder().encode(clipboardSourceList) {
                defaults.set(data, forKey: Keys.clipboardSourceList)
            }
        }
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
            ,
            Keys.typingEffect: TypingEffect.off.rawValue,
            Keys.inlineCalculations: true,
            Keys.inlineBrandIcons: true,
            Keys.clipboardDrawerEdge: ClipboardDrawerEdge.top.rawValue,
            Keys.clipboardMaxItems: 500,
            Keys.clipboardMaxAgeDays: 30,
            Keys.clipboardSourceMode: ClipboardSourceMode.allowAll.rawValue
        ])

        scribblyModeActive = defaults.bool(forKey: Keys.scribblyModeActive)
        hideActionBar = defaults.bool(forKey: Keys.hideActionBar)
        listItemPrefix = defaults.string(forKey: Keys.listItemPrefix) ?? " • "

        let languageRaw = defaults.string(forKey: Keys.selectedLanguage) ?? AppLanguage.english.rawValue
        selectedLanguage = AppLanguage(rawValue: languageRaw) ?? .english
        shortcuts = Self.loadShortcuts(from: defaults)
        storageDirectoryPath = defaults.string(forKey: Keys.storageDirectory) ?? ""
        randomizeNewNotePosition = defaults.bool(forKey: Keys.randomizeNewNotePosition)
        let effectRaw = defaults.string(forKey: Keys.typingEffect) ?? TypingEffect.off.rawValue
        typingEffect = TypingEffect(rawValue: effectRaw) ?? .off
        inlineCalculations = defaults.bool(forKey: Keys.inlineCalculations)
        inlineBrandIcons = defaults.bool(forKey: Keys.inlineBrandIcons)
        let edgeRaw = defaults.string(forKey: Keys.clipboardDrawerEdge) ?? ClipboardDrawerEdge.top.rawValue
        clipboardDrawerEdge = ClipboardDrawerEdge(rawValue: edgeRaw) ?? .top
        clipboardMaxItems = max(50, defaults.integer(forKey: Keys.clipboardMaxItems))
        clipboardMaxAgeDays = max(1, defaults.integer(forKey: Keys.clipboardMaxAgeDays))
        let sourceModeRaw = defaults.string(forKey: Keys.clipboardSourceMode) ?? ClipboardSourceMode.allowAll.rawValue
        clipboardSourceMode = ClipboardSourceMode(rawValue: sourceModeRaw) ?? .allowAll
        if let data = defaults.data(forKey: Keys.clipboardSourceList),
           let list = try? JSONDecoder().decode([String].self, from: data) {
            clipboardSourceList = list
        } else {
            clipboardSourceList = []
        }

        applyLanguagePreference()
    }

    private func applyLanguagePreference() {
        LocalizationController.shared.setLanguage(code: selectedLanguage.rawValue)

        // Best-effort: also update system localization preferences for formatters, etc.
        defaults.set([selectedLanguage.rawValue], forKey: "AppleLanguages")
        defaults.set(selectedLanguage.rawValue, forKey: "AppleLocale")
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

enum ClipboardDrawerEdge: String, CaseIterable, Identifiable {
    case top
    case bottom
    case left
    case right

    var id: String { rawValue }
}

enum ClipboardSourceMode: String, CaseIterable, Identifiable {
    case allowAll
    case blockList
    case allowList

    var id: String { rawValue }
}

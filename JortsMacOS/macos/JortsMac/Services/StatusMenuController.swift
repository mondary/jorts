import AppKit

final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private weak var manager: NoteManager?

    private let onNewNote: () -> Void
    private let onShowAllNotes: () -> Void
    private let onSaveAllNotes: () -> Void
    private let onShowSettings: () -> Void
    private let onShowAbout: () -> Void
    private let onRestart: () -> Void
    private let onShowList: () -> Void
    private let onShowClipboard: () -> Void
    private let onQuit: () -> Void
    private let settings: AppSettings

    init(
        manager: NoteManager,
        onNewNote: @escaping () -> Void,
        onShowAllNotes: @escaping () -> Void,
        onSaveAllNotes: @escaping () -> Void,
        onShowSettings: @escaping () -> Void,
        onShowAbout: @escaping () -> Void,
        onRestart: @escaping () -> Void,
        onShowList: @escaping () -> Void,
        onShowClipboard: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        settings: AppSettings
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: 26)
        self.manager = manager
        self.onNewNote = onNewNote
        self.onShowAllNotes = onShowAllNotes
        self.onSaveAllNotes = onSaveAllNotes
        self.onShowSettings = onShowSettings
        self.onShowAbout = onShowAbout
        self.onRestart = onRestart
        self.onShowList = onShowList
        self.onShowClipboard = onShowClipboard
        self.onQuit = onQuit
        self.settings = settings

        super.init()

        if let button = statusItem.button {
            button.image = Self.statusIcon()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyUpOrDown
            button.toolTip = "JortsMacOS"
        }

        menu.delegate = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    @objc private func openNote(_ sender: NSMenuItem) {
        guard let uuidString = sender.representedObject as? String,
              let noteID = UUID(uuidString: uuidString) else {
            return
        }

        manager?.focusNote(documentID: noteID)
    }

    @objc private func newNote(_ sender: NSMenuItem) {
        onNewNote()
    }

    @objc private func showAllNotes(_ sender: NSMenuItem) {
        onShowAllNotes()
    }

    @objc private func saveAllNotes(_ sender: NSMenuItem) {
        onSaveAllNotes()
    }

    @objc private func showSettings(_ sender: NSMenuItem) {
        onShowSettings()
    }

    @objc private func showAbout(_ sender: NSMenuItem) {
        onShowAbout()
    }

    @objc private func quit(_ sender: NSMenuItem) {
        onQuit()
    }

    @objc private func restart(_ sender: NSMenuItem) {
        onRestart()
    }

    @objc private func showList(_ sender: NSMenuItem) {
        onShowList()
    }

    @objc private func showClipboard(_ sender: NSMenuItem) {
        onShowClipboard()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let notes = manager?.menuEntries() ?? []

        if notes.isEmpty {
            let emptyItem = NSMenuItem(title: localizedString("no_notes"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for note in notes {
                let item = NSMenuItem(
                    title: note.title.truncatedForMenu,
                    action: #selector(openNote(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = note.id.uuidString
                item.image = note.theme.menuSwatchImage
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(actionItem(localizedString("new_note"), action: #selector(newNote(_:)), shortcut: .newStickyNote))
        menu.addItem(actionItem(localizedString("show_all_notes"), action: #selector(showAllNotes(_:)), shortcut: .showAllNotes))
        menu.addItem(actionItem(localizedString("show_list"), action: #selector(showList(_:)), shortcut: .showNotesList))
        menu.addItem(actionItem(localizedString("show_clipboard_drawer"), action: #selector(showClipboard(_:)), keyEquivalent: "v", modifiers: [.command, .shift], systemImage: "clipboard"))
        menu.addItem(.separator())
        menu.addItem(actionItem(localizedString("settings"), action: #selector(showSettings(_:)), shortcut: .preferences, systemImage: "gearshape"))
        menu.addItem(actionItem(localizedString("about_jortsmacos"), action: #selector(showAbout(_:)), keyEquivalent: ""))
        menu.addItem(actionItem(localizedString("restart_jortsmacos"), action: #selector(restart(_:)), keyEquivalent: ""))
        menu.addItem(actionItem(localizedString("quit_jortsmacos"), action: #selector(quit(_:)), keyEquivalent: "q"))
    }

    private func actionItem(
        _ title: String,
        action: Selector,
        shortcut actionShortcut: ShortcutAction,
        systemImage: String? = nil
    ) -> NSMenuItem {
        let shortcut = settings.shortcut(for: actionShortcut)
        return actionItem(
            title,
            action: action,
            keyEquivalent: shortcut.normalizedKey,
            modifiers: shortcut.modifier.flags,
            systemImage: systemImage
        )
    }

    private func actionItem(
        _ title: String,
        action: Selector,
        keyEquivalent: String,
        modifiers: NSEvent.ModifierFlags = [.command],
        systemImage: String? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.keyEquivalentModifierMask = keyEquivalent.isEmpty ? [] : modifiers
        if let systemImage {
            item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        }
        return item
    }

    private static func statusIcon() -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let symbol = NSImage(systemSymbolName: "note.text", accessibilityDescription: "JortsMacOS")?
            .withSymbolConfiguration(configuration)

        if let appIcon = Bundle.main.url(forResource: "JortsStatus", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:)) {
            let image = resizedStatusIcon(from: appIcon)
            image.isTemplate = false
            return image
        }

        if let appIcon = NSApp.applicationIconImage, appIcon.size.width > 0, appIcon.size.height > 0 {
            let image = resizedStatusIcon(from: appIcon)
            image.isTemplate = false
            return image
        }

        let fallback = symbol ?? NSImage(size: NSSize(width: 18, height: 18))
        fallback.isTemplate = true
        return fallback
    }

    private static func resizedStatusIcon(from source: NSImage) -> NSImage {
        let targetSize = NSSize(width: 18, height: 18)
        let image = NSImage(size: targetSize)
        image.lockFocus()
        source.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: source.size),
            operation: .sourceOver,
            fraction: 1.0
        )
        image.unlockFocus()
        return image
    }
}

private extension String {
    var truncatedForMenu: String {
        let fallback = trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : self
        guard fallback.count > 42 else {
            return fallback
        }

        let prefix = fallback.prefix(39)
        return "\(prefix)…"
    }
}

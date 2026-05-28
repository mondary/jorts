import AppKit
import Combine
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private lazy var manager = NoteManager(settings: settings)
    private var preferencesWindowController: PreferencesWindowController?
    private var notesListWindowController: NotesListWindowController?
    private var commandPaletteWindowController: CommandPaletteWindowController?
    private var clipboardWindowController: ClipboardWindowController?
    private var statusMenuController: StatusMenuController?
    private var cancellables: Set<AnyCancellable> = []
    private var globalHotKeyNewRef: EventHotKeyRef?
    private var globalHotKeyLastRef: EventHotKeyRef?
    private var globalHotKeyClipboardRef: EventHotKeyRef?
    private var globalHotKeyHandlerRef: EventHandlerRef?
    private lazy var clipboard = ClipboardManager(
        persistence: ClipboardPersistence(baseDirectory: manager.storageURL.deletingLastPathComponent())
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        FontRegistrar.registerBundledFonts()
        observeSettings()
        buildMainMenu()
        manager.onShowList = { [weak self] in self?.showNotesList(nil) }
        manager.launch()
        buildStatusMenu()
        registerGlobalHotKey()
        donateSpotlightActivities()
        clipboard.start()
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        // Enables Raycast / Alfred / scripts via: open "jortsmacos://new"
        for url in urls {
            handleExternalURL(url)
        }
    }

    func application(
        _ application: NSApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void
    ) -> Bool {
        // Enables Spotlight suggestions / Siri predictions when the activity is donated.
        if handleExternalUserActivity(userActivity) {
            return true
        }
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            manager.showAllNotes()
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        manager.saveNow()
        return .terminateNow
    }

    @objc private func showAbout(_ sender: Any?) {
        let credits = NSMutableAttributedString()

        let header = "JortsMacOS\n\n"
        let headerAttr: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 13)]
        credits.append(NSAttributedString(string: header, attributes: headerAttr))

        let description = "Native macOS Swift port\n\n"
        credits.append(NSAttributedString(string: description))

        let originalText = "Original project: "
        credits.append(NSAttributedString(string: originalText))

        let originalLink = "elly-code/jorts\n"
        if let originalURL = URL(string: "https://github.com/elly-code/jorts") {
            let originalLinkAttr: [NSAttributedString.Key: Any] = [
                .link: originalURL,
                .foregroundColor: NSColor.systemBlue,
                .font: NSFont.systemFont(ofSize: 11)
            ]
            credits.append(NSAttributedString(string: originalLink, attributes: originalLinkAttr))
        }

        let forkText = "macOS fork: "
        credits.append(NSAttributedString(string: forkText))

        let forkLink = "clm-tmp/JORTS_macos"
        if let forkURL = URL(string: "https://github.com/clm-tmp/JORTS_macos") {
            let forkLinkAttr: [NSAttributedString.Key: Any] = [
                .link: forkURL,
                .foregroundColor: NSColor.systemBlue,
                .font: NSFont.systemFont(ofSize: 11)
            ]
            credits.append(NSAttributedString(string: forkLink, attributes: forkLinkAttr))
        }

        credits.append(NSAttributedString(string: "\n"))

        let supportText = "☕ Support the original developer: "
        credits.append(NSAttributedString(string: supportText))

        let supportLink = "ko-fi.com/teamcons"
        if let supportURL = URL(string: "https://ko-fi.com/teamcons/tip") {
            let supportLinkAttr: [NSAttributedString.Key: Any] = [
                .link: supportURL,
                .foregroundColor: NSColor.systemBlue,
                .font: NSFont.systemFont(ofSize: 11)
            ]
            credits.append(NSAttributedString(string: supportLink, attributes: supportLinkAttr))
        }

        credits.append(NSAttributedString(string: "\n"))

        let forkSupportText = "☕ Support this macOS fork: "
        credits.append(NSAttributedString(string: forkSupportText))

        let forkSupportLink = "ko-fi.com/pouark"
        if let forkSupportURL = URL(string: "https://ko-fi.com/pouark") {
            let forkSupportAttr: [NSAttributedString.Key: Any] = [
                .link: forkSupportURL,
                .foregroundColor: NSColor.systemBlue,
                .font: NSFont.systemFont(ofSize: 11)
            ]
            credits.append(NSAttributedString(string: forkSupportLink, attributes: forkSupportAttr))
        }

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "JortsMacOS",
            .applicationVersion: "4.2.0 macOS port",
            .credits: credits
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func newNote(_ sender: Any?) {
        manager.createNote()
    }

    private func registerGlobalHotKey() {
        // Global shortcuts.
        // Warning: these can conflict with some input source / system shortcuts.
        let signature = OSType("JRTS".fourCharCodeValue)
        let focusLastShortcut = settings.shortcut(for: .focusLastNoteGlobal)
        let newNoteShortcut = settings.shortcut(for: .newNoteGlobal)

        // Focus last note (or create if none)
        let newID = EventHotKeyID(signature: signature, id: 1)
        let focusStatus = RegisterEventHotKey(
            keyCode(for: focusLastShortcut.key),
            focusLastShortcut.modifier.carbonFlags,
            newID,
            GetApplicationEventTarget(),
            0,
            &globalHotKeyNewRef
        )
        if focusStatus != noErr { globalHotKeyNewRef = nil }

        // New note
        let lastID = EventHotKeyID(signature: signature, id: 2)
        let newStatus = RegisterEventHotKey(
            keyCode(for: newNoteShortcut.key),
            newNoteShortcut.modifier.carbonFlags,
            lastID,
            GetApplicationEventTarget(),
            0,
            &globalHotKeyLastRef
        )
        if newStatus != noErr { globalHotKeyLastRef = nil }

        // Clipboard drawer (fixed global shortcut for now)
        let clipboardID = EventHotKeyID(signature: signature, id: 3)
        let clipboardStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            clipboardID,
            GetApplicationEventTarget(),
            0,
            &globalHotKeyClipboardRef
        )
        if clipboardStatus != noErr { globalHotKeyClipboardRef = nil }

        installGlobalHotKeyHandlerIfNeeded()
    }

    private func unregisterGlobalHotKeys() {
        if let globalHotKeyNewRef {
            UnregisterEventHotKey(globalHotKeyNewRef)
            self.globalHotKeyNewRef = nil
        }
        if let globalHotKeyLastRef {
            UnregisterEventHotKey(globalHotKeyLastRef)
            self.globalHotKeyLastRef = nil
        }
        if let globalHotKeyClipboardRef {
            UnregisterEventHotKey(globalHotKeyClipboardRef)
            self.globalHotKeyClipboardRef = nil
        }
    }

    private func installGlobalHotKeyHandlerIfNeeded() {
        guard globalHotKeyHandlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, eventRef, userData in
            guard let userData else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            delegate.handleGlobalHotKey(eventRef)
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &globalHotKeyHandlerRef
        )
    }

    private func keyCode(for key: String) -> UInt32 {
        switch key.lowercased() {
        case "space": return UInt32(kVK_Space)
        case "0": return UInt32(kVK_ANSI_0)
        case "1": return UInt32(kVK_ANSI_1)
        case "2": return UInt32(kVK_ANSI_2)
        case "3": return UInt32(kVK_ANSI_3)
        case "4": return UInt32(kVK_ANSI_4)
        case "5": return UInt32(kVK_ANSI_5)
        case "6": return UInt32(kVK_ANSI_6)
        case "7": return UInt32(kVK_ANSI_7)
        case "8": return UInt32(kVK_ANSI_8)
        case "9": return UInt32(kVK_ANSI_9)
        case "a": return UInt32(kVK_ANSI_A)
        case "b": return UInt32(kVK_ANSI_B)
        case "c": return UInt32(kVK_ANSI_C)
        case "d": return UInt32(kVK_ANSI_D)
        case "e": return UInt32(kVK_ANSI_E)
        case "f": return UInt32(kVK_ANSI_F)
        case "g": return UInt32(kVK_ANSI_G)
        case "h": return UInt32(kVK_ANSI_H)
        case "i": return UInt32(kVK_ANSI_I)
        case "j": return UInt32(kVK_ANSI_J)
        case "k": return UInt32(kVK_ANSI_K)
        case "l": return UInt32(kVK_ANSI_L)
        case "m": return UInt32(kVK_ANSI_M)
        case "n": return UInt32(kVK_ANSI_N)
        case "o": return UInt32(kVK_ANSI_O)
        case "p": return UInt32(kVK_ANSI_P)
        case "q": return UInt32(kVK_ANSI_Q)
        case "r": return UInt32(kVK_ANSI_R)
        case "s": return UInt32(kVK_ANSI_S)
        case "t": return UInt32(kVK_ANSI_T)
        case "u": return UInt32(kVK_ANSI_U)
        case "v": return UInt32(kVK_ANSI_V)
        case "w": return UInt32(kVK_ANSI_W)
        case "x": return UInt32(kVK_ANSI_X)
        case "y": return UInt32(kVK_ANSI_Y)
        case "z": return UInt32(kVK_ANSI_Z)
        default: return UInt32(kVK_Space)
        }
    }

    private func handleGlobalHotKey(_ event: EventRef?) {
        guard let event else { return }
        let frontmostAppBeforeHandling = NSWorkspace.shared.frontmostApplication
        let keyWindowBeforeHandling = NSApp.keyWindow
        let firstResponderBeforeHandling = keyWindowBeforeHandling?.firstResponder
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr else { return }
        guard hotKeyID.signature == OSType("JRTS".fourCharCodeValue) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch hotKeyID.id {
            case 1:
                self.manager.focusLastFocusedNote()
            case 2:
                self.manager.createNote()
            case 3:
                self.showClipboard(
                    targetApp: frontmostAppBeforeHandling,
                    targetWindow: keyWindowBeforeHandling,
                    targetResponder: firstResponderBeforeHandling
                )
            default:
                break
            }
        }
    }

    @objc private func saveAll(_ sender: Any?) {
        manager.saveNow()
    }

    @objc private func showAllNotes(_ sender: Any?) {
        manager.showAllNotes()
    }

    @objc private func showPreferences(_ sender: Any?) {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(
                settings: settings,
                storageURL: manager.storageURL,
                onLanguageChanged: { [weak self] in
                    self?.restartForLanguageChange()
                }
            )
        }

        preferencesWindowController?.showWindow(nil)
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func restartForLanguageChange() {
        manager.saveNow()

        let alert = NSAlert()
        alert.messageText = "Language Changed"
        alert.informativeText = "JortsMacOS needs to restart to apply the language change."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Restart Now")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            restartApp(nil)
        }
    }

    @objc private func closeCurrentNoteWindow(_ sender: Any?) {
        NSApp.keyWindow?.performClose(sender)
    }

    @objc private func deleteCurrentNote(_ sender: Any?) {
        manager.deleteActiveNote()
    }

    @objc private func toggleCurrentList(_ sender: Any?) {
        manager.toggleListForActiveNote()
    }

    @objc private func toggleCurrentMonospace(_ sender: Any?) {
        manager.toggleMonospaceForActiveNote()
    }

    @objc private func zoomIn(_ sender: Any?) {
        manager.zoomActiveNote(by: 20)
    }

    @objc private func zoomOut(_ sender: Any?) {
        manager.zoomActiveNote(by: -20)
    }

    @objc private func zoomDefault(_ sender: Any?) {
        manager.resetZoomForActiveNote()
    }

    @objc private func showCharacterPalette(_ sender: Any?) {
        NSApp.orderFrontCharacterPalette(sender)
    }

    @objc private func restartApp(_ sender: Any?) {
        manager.saveNow()

        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()

        NSApp.terminate(nil)
    }

    @objc private func showNotesList(_ sender: Any?) {
        if notesListWindowController == nil {
            notesListWindowController = NotesListWindowController(
                manager: manager,
                settings: settings,
                onShowPreferences: { [weak self] in self?.showPreferences(nil) },
                onNoteSelected: { [weak self] noteID in
                    self?.manager.focusNote(documentID: noteID)
                }
            )
        }

        notesListWindowController?.showWindow(nil)
        notesListWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showClipboard(_ sender: Any?) {
        showClipboard(
            targetApp: NSWorkspace.shared.frontmostApplication,
            targetWindow: NSApp.keyWindow,
            targetResponder: NSApp.keyWindow?.firstResponder
        )
    }

    private func showClipboard(targetApp: NSRunningApplication?, targetWindow: NSWindow?, targetResponder: NSResponder?) {
        if clipboardWindowController == nil {
            clipboardWindowController = ClipboardWindowController(manager: manager, settings: settings, clipboard: clipboard)
        }
        clipboardWindowController?.toggle(
            targetApp: targetApp,
            targetWindow: targetWindow,
            targetResponder: targetResponder
        )
    }

    private func observeSettings() {
        settings.$shortcuts
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.buildMainMenu()
                self?.buildStatusMenu()
                self?.unregisterGlobalHotKeys()
                self?.registerGlobalHotKey()
            }
            .store(in: &cancellables)

        settings.$clipboardMaxItems
            .combineLatest(settings.$clipboardMaxAgeDays, settings.$clipboardSourceMode, settings.$clipboardSourceList)
            .receive(on: RunLoop.main)
            .sink { [weak self] maxItems, maxDays, mode, list in
                self?.clipboard.setConfig(maxItems: maxItems, maxAgeDays: maxDays, sourceMode: mode, sourceList: list)
            }
            .store(in: &cancellables)
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(menuItem(localizedString("about_jortsmacos"), action: #selector(showAbout(_:)), key: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(menuItem(localizedString("preferences"), action: #selector(showPreferences(_:)), shortcut: .preferences))
        appMenu.addItem(.separator())

        let servicesItem = NSMenuItem(title: localizedString("services"), action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: localizedString("services"))
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu

        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: localizedString("hide_jortsmacos"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthers = NSMenuItem(
            title: localizedString("hide_others"),
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(NSMenuItem(title: localizedString("show_all"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: localizedString("quit_jortsmacos"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: localizedString("file"))
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(menuItem(localizedString("new_sticky_note"), action: #selector(newNote(_:)), shortcut: .newStickyNote))
        fileMenu.addItem(menuItem(localizedString("save_all_notes"), action: #selector(saveAll(_:)), shortcut: .saveAllNotes))
        fileMenu.addItem(.separator())
        fileMenu.addItem(menuItem(localizedString("close_note_window"), action: #selector(closeCurrentNoteWindow(_:)), shortcut: .closeNoteWindow))
        fileMenu.addItem(menuItem(localizedString("delete_sticky_note"), action: #selector(deleteCurrentNote(_:)), shortcut: .deleteStickyNote))

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: localizedString("edit"))
        editMenuItem.submenu = editMenu
        editMenu.addItem(responderItem(localizedString("undo"), action: Selector(("undo:")), key: "z"))
        editMenu.addItem(responderItem(localizedString("redo"), action: Selector(("redo:")), key: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(responderItem(localizedString("cut"), action: #selector(NSText.cut(_:)), key: "x"))
        editMenu.addItem(responderItem(localizedString("copy"), action: #selector(NSText.copy(_:)), key: "c"))
        editMenu.addItem(responderItem(localizedString("paste"), action: #selector(NSText.paste(_:)), key: "v"))
        editMenu.addItem(responderItem(localizedString("select_all"), action: #selector(NSText.selectAll(_:)), key: "a"))
        editMenu.addItem(.separator())
        editMenu.addItem(menuItem(localizedString("toggle_list"), action: #selector(toggleCurrentList(_:)), shortcut: .toggleList))
        editMenu.addItem(menuItem(localizedString("emoji_symbols"), action: #selector(showCharacterPalette(_:)), shortcut: .emojiSymbols))

        let noteMenuItem = NSMenuItem()
        mainMenu.addItem(noteMenuItem)
        let noteMenu = NSMenu(title: localizedString("shortcut_group_note"))
        noteMenuItem.submenu = noteMenu
        noteMenu.addItem(menuItem(localizedString("toggle_monospace"), action: #selector(toggleCurrentMonospace(_:)), shortcut: .toggleMonospace))
        noteMenu.addItem(.separator())
        noteMenu.addItem(menuItem(localizedString("zoom_in"), action: #selector(zoomIn(_:)), shortcut: .zoomIn))
        noteMenu.addItem(menuItem(localizedString("zoom_out"), action: #selector(zoomOut(_:)), shortcut: .zoomOut))
        noteMenu.addItem(menuItem(localizedString("actual_size"), action: #selector(zoomDefault(_:)), shortcut: .actualSize))

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: localizedString("window"))
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(menuItem(localizedString("show_all_notes"), action: #selector(showAllNotes(_:)), shortcut: .showAllNotes))
        windowMenu.addItem(menuItem(localizedString("show_notes_list"), action: #selector(showNotesList(_:)), shortcut: .showNotesList))
        windowMenu.addItem(menuItem(localizedString("clipboard"), action: #selector(showClipboard(_:)), key: "v", modifiers: [.command, .shift]))
        windowMenu.addItem(.separator())
        windowMenu.addItem(menuItem(localizedString("command_palette"), action: #selector(showCommandPalette(_:)), key: "k", modifiers: [.command]))
        windowMenu.addItem(.separator())
        windowMenu.addItem(responderItem(localizedString("minimize"), action: #selector(NSWindow.miniaturize(_:)), key: "m"))
        windowMenu.addItem(responderItem(localizedString("zoom"), action: #selector(NSWindow.performZoom(_:)), key: ""))
        NSApp.windowsMenu = windowMenu
    }

    @objc private func showCommandPalette(_ sender: Any?) {
        if commandPaletteWindowController == nil {
            commandPaletteWindowController = CommandPaletteWindowController(manager: manager)
        }
        commandPaletteWindowController?.showWindow(sender)
    }

    private func buildStatusMenu() {
        statusMenuController = StatusMenuController(
            manager: manager,
            onNewNote: { [weak self] in self?.manager.createNote() },
            onShowAllNotes: { [weak self] in self?.manager.showAllNotes() },
            onSaveAllNotes: { [weak self] in self?.manager.saveNow() },
            onShowSettings: { [weak self] in self?.showPreferences(nil) },
            onShowAbout: { [weak self] in self?.showAbout(nil) },
            onRestart: { [weak self] in self?.restartApp(nil) },
            onShowList: { [weak self] in self?.showNotesList(nil) },
            onQuit: { NSApp.terminate(nil) },
            settings: settings
        )
    }

    private func menuItem(_ title: String, action: Selector, shortcut actionShortcut: ShortcutAction) -> NSMenuItem {
        let shortcut = settings.shortcut(for: actionShortcut)
        return menuItem(title, action: action, key: shortcut.normalizedKey, modifiers: shortcut.modifier.flags)
    }

    private func menuItem(
        _ title: String,
        action: Selector,
        key: String,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        return item
    }

    private func responderItem(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = nil
        return item
    }

    // MARK: - External Automation (URL Scheme + Spotlight/Raycast/Alfred)

    private enum ExternalAction: String {
        case new
        case last
        case list
        case clipboard
    }

    private func handleExternalURL(_ url: URL) {
        // Expected:
        // - jortsmacos://new
        // - jortsmacos://last
        // - jortsmacos://list
        guard url.scheme?.lowercased() == "jortsmacos" else { return }

        let raw = (url.host?.isEmpty == false ? url.host! : url.path)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()

        guard let action = ExternalAction(rawValue: raw) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.performExternalAction(action)
        }
    }

    private func handleExternalUserActivity(_ activity: NSUserActivity) -> Bool {
        // Activity types are declared in Info.plist (generated) and donated at launch.
        let type = activity.activityType.lowercased()
        if type.hasSuffix(".newnote") || type.hasSuffix(".new_note") {
            performExternalAction(.new)
            return true
        }
        if type.hasSuffix(".lastnote") || type.hasSuffix(".last_note") {
            performExternalAction(.last)
            return true
        }
        if type.hasSuffix(".noteslist") || type.hasSuffix(".notes_list") {
            performExternalAction(.list)
            return true
        }
        if type.hasSuffix(".clipboard") {
            performExternalAction(.clipboard)
            return true
        }
        return false
    }

    private func performExternalAction(_ action: ExternalAction) {
        switch action {
        case .new:
            NSApp.activate(ignoringOtherApps: true)
            manager.createNote()
        case .last:
            NSApp.activate(ignoringOtherApps: true)
            manager.focusLastFocusedNote()
        case .list:
            NSApp.activate(ignoringOtherApps: true)
            showNotesList(nil)
        case .clipboard:
            showClipboard(
                targetApp: NSWorkspace.shared.frontmostApplication,
                targetWindow: NSApp.keyWindow,
                targetResponder: NSApp.keyWindow?.firstResponder
            )
        }
    }

    private func donateSpotlightActivities() {
        // Donated activities make Spotlight/Raycast/Alfred suggestions possible. Raycast/Alfred
        // can also call us via the URL scheme, which is more deterministic.
        let bundleID = Bundle.main.bundleIdentifier ?? "io.github.ellycode.jorts.macos"

        let activities: [(id: String, titleKey: String)] = [
            ("\(bundleID).newNote", "new_note"),
            ("\(bundleID).lastNote", "reopen_last_note"),
            ("\(bundleID).notesList", "show_notes_list"),
            ("\(bundleID).clipboard", "clipboard")
        ]

        for (id, titleKey) in activities {
            let activity = NSUserActivity(activityType: id)
            activity.title = localizedString(titleKey)
            activity.isEligibleForSearch = true
            activity.persistentIdentifier = NSUserActivityPersistentIdentifier(id)
            activity.becomeCurrent()
        }
    }
}

private extension String {
    var fourCharCodeValue: UInt32 {
        var result: UInt32 = 0
        for scalar in unicodeScalars.prefix(4) {
            result = (result << 8) + scalar.value
        }
        return result
    }
}

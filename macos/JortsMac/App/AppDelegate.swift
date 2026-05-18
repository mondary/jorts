import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private lazy var manager = NoteManager(settings: settings)
    private var preferencesWindowController: PreferencesWindowController?
    private var statusMenuController: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        FontRegistrar.registerBundledFonts()
        buildMainMenu()
        manager.launch()
        buildStatusMenu()
        NSApp.activate(ignoringOtherApps: true)
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
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Jorts",
            .applicationVersion: "4.2.0 macOS port",
            .credits: NSAttributedString(string: "Native macOS Swift port of elly-code/jorts.")
        ])
    }

    @objc private func newNote(_ sender: Any?) {
        manager.createNote()
    }

    @objc private func saveAll(_ sender: Any?) {
        manager.saveNow()
    }

    @objc private func showPreferences(_ sender: Any?) {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(
                settings: settings,
                storageURL: manager.storageURL
            )
        }

        preferencesWindowController?.showWindow(nil)
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

    private func buildMainMenu() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(menuItem("About Jorts", action: #selector(showAbout(_:)), key: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(menuItem("Preferences…", action: #selector(showPreferences(_:)), key: ","))
        appMenu.addItem(.separator())

        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu

        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Hide Jorts", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthers = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Jorts", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(menuItem("New Sticky Note", action: #selector(newNote(_:)), key: "n"))
        fileMenu.addItem(menuItem("Save All Notes", action: #selector(saveAll(_:)), key: "s"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(menuItem("Close Note Window", action: #selector(closeCurrentNoteWindow(_:)), key: "w"))
        fileMenu.addItem(menuItem("Delete Sticky Note", action: #selector(deleteCurrentNote(_:)), key: "\u{8}"))

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(responderItem("Undo", action: Selector(("undo:")), key: "z"))
        editMenu.addItem(responderItem("Redo", action: Selector(("redo:")), key: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(responderItem("Cut", action: #selector(NSText.cut(_:)), key: "x"))
        editMenu.addItem(responderItem("Copy", action: #selector(NSText.copy(_:)), key: "c"))
        editMenu.addItem(responderItem("Paste", action: #selector(NSText.paste(_:)), key: "v"))
        editMenu.addItem(responderItem("Select All", action: #selector(NSText.selectAll(_:)), key: "a"))
        editMenu.addItem(.separator())
        editMenu.addItem(menuItem("Toggle List", action: #selector(toggleCurrentList(_:)), key: "l", modifiers: [.command, .shift]))
        editMenu.addItem(menuItem("Emoji & Symbols", action: #selector(showCharacterPalette(_:)), key: " ", modifiers: [.command, .control]))

        let noteMenuItem = NSMenuItem()
        mainMenu.addItem(noteMenuItem)
        let noteMenu = NSMenu(title: "Note")
        noteMenuItem.submenu = noteMenu
        noteMenu.addItem(menuItem("Toggle Monospace", action: #selector(toggleCurrentMonospace(_:)), key: "m"))
        noteMenu.addItem(.separator())
        noteMenu.addItem(menuItem("Zoom In", action: #selector(zoomIn(_:)), key: "+"))
        noteMenu.addItem(menuItem("Zoom Out", action: #selector(zoomOut(_:)), key: "-"))
        noteMenu.addItem(menuItem("Actual Size", action: #selector(zoomDefault(_:)), key: "0"))

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(responderItem("Minimize", action: #selector(NSWindow.miniaturize(_:)), key: "m"))
        windowMenu.addItem(responderItem("Zoom", action: #selector(NSWindow.performZoom(_:)), key: ""))
        NSApp.windowsMenu = windowMenu
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
            onQuit: { NSApp.terminate(nil) }
        )
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
}

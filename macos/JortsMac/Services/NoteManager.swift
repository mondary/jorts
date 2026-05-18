import AppKit

final class NoteManager {
    private let settings: AppSettings
    private let storage: NoteStorage
    private var controllers: [UUID: NoteWindowController] = [:]
    private var saveWorkItem: DispatchWorkItem?
    private var latestTheme: NoteTheme = .blueberry

    var storageURL: URL {
        storage.storageURL
    }

    init(settings: AppSettings, storage: NoteStorage = NoteStorage()) {
        self.settings = settings
        self.storage = storage
    }

    func launch() {
        let loadedNotes = storage.load()

        if loadedNotes.isEmpty {
            createNote(NoteData(theme: .blueberry), activate: true, scheduleSave: true)
        } else {
            loadedNotes.forEach { createNote($0, activate: false, scheduleSave: false) }
            showAllNotes()
        }
    }

    func createNote() {
        let note = RandomContent.newNoteData(skipping: latestTheme)
        createNote(note, activate: true, scheduleSave: true)
    }

    func createNote(_ data: NoteData, activate: Bool = true, scheduleSave: Bool = true) {
        latestTheme = data.theme
        let document = NoteDocument(data: data)
        let controller = NoteWindowController(
            document: document,
            settings: settings,
            onNew: { [weak self] in self?.createNote() },
            onDelete: { [weak self, weak document] in
                guard let document else { return }
                self?.deleteNote(documentID: document.id)
            },
            onSave: { [weak self] in self?.saveNow() },
            onShowEmoji: { NSApp.orderFrontCharacterPalette(nil) },
            onDocumentChanged: { [weak self, weak document] in
                guard let document else { return }
                self?.latestTheme = document.theme
                self?.scheduleSave()
            }
        )

        controllers[document.id] = controller
        controller.showWindow(nil)

        if activate {
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        if scheduleSave {
            self.scheduleSave()
        }
    }

    func showAllNotes() {
        if controllers.isEmpty {
            createNote(NoteData(theme: .blueberry), activate: true, scheduleSave: true)
            return
        }

        controllers.values.forEach { controller in
            controller.showWindow(nil)
            controller.window?.orderFront(nil)
        }

        controllers.values.first?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func deleteActiveNote() {
        guard let controller = activeController() else {
            return
        }

        deleteNote(documentID: controller.noteDocument.id)
    }

    func deleteNote(documentID: UUID) {
        guard let controller = controllers.removeValue(forKey: documentID) else {
            return
        }

        controller.closeForDelete()
        saveNow()
    }

    func toggleListForActiveNote() {
        activeController()?.noteDocument.toggleList()
    }

    func toggleMonospaceForActiveNote() {
        guard let document = activeController()?.noteDocument else {
            return
        }

        document.monospace.toggle()
    }

    func zoomActiveNote(by delta: Int) {
        guard let document = activeController()?.noteDocument else {
            return
        }

        if delta > 0 {
            document.zoomIn()
        } else {
            document.zoomOut()
        }
    }

    func resetZoomForActiveNote() {
        activeController()?.noteDocument.resetZoom()
    }

    func scheduleSave() {
        saveWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }

        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(900), execute: workItem)
    }

    func saveNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        storage.save(controllers.values.map { $0.noteDocument.package() })
    }

    private func activeController() -> NoteWindowController? {
        if let keyWindow = NSApp.keyWindow,
           let controller = controllers.values.first(where: { $0.window === keyWindow }) {
            return controller
        }

        if let mainWindow = NSApp.mainWindow,
           let controller = controllers.values.first(where: { $0.window === mainWindow }) {
            return controller
        }

        return controllers.values.first
    }
}

import AppKit

final class NoteManager {
    private let settings: AppSettings
    private let storage: NoteStorage
    private var controllers: [UUID: NoteWindowController] = [:]
    private var orderedNoteIDs: [UUID] = []
    private var trash: [TrashedNote] = []
    private var saveWorkItem: DispatchWorkItem?
    private var latestTheme: NoteTheme = .blueberry
    private let maxVersionsPerNote = 25
    private var lastFocusedNoteID: UUID?

    var onShowList: (() -> Void)?

    var storageURL: URL {
        storage.storageURL
    }

    init(settings: AppSettings, storage: NoteStorage? = nil) {
        self.settings = settings
        self.storage = storage ?? NoteStorage(storageDirectoryOverride: settings.storageDirectoryURL)
    }

    func launch() {
        let state = storage.loadState()
        trash = state.trash
        let loadedNotes = state.notes

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
            onShowList: { [weak self] in self?.onShowList?() },
            onBecameKey: { [weak self] id in
                self?.lastFocusedNoteID = id
            },
            onDocumentChanged: { [weak self, weak document] in
                guard let document else { return }
                self?.latestTheme = document.theme
                self?.scheduleSave()
            }
        )

        document.onVersionSuggested = { [weak self, weak document] in
            guard let document else { return }
            self?.appendVersion(for: document)
        }

        controllers[document.id] = controller
        orderedNoteIDs.append(document.id)
        controller.showWindow(nil)

        if activate {
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            lastFocusedNoteID = document.id
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

        orderedControllers().forEach { controller in
            controller.showWindow(nil)
            controller.window?.orderFront(nil)
        }

        orderedControllers().first?.window?.makeKeyAndOrderFront(nil)
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

        orderedNoteIDs.removeAll { $0 == documentID }
        let data = controller.noteDocument.package()
        trash.insert(TrashedNote(note: data), at: 0)
        controller.closeForDelete()
        saveNow()
    }

    func focusNote(documentID: UUID) {
        guard let controller = controllers[documentID] else {
            return
        }

        controller.showWindow(nil)
        controller.window?.deminiaturize(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        lastFocusedNoteID = documentID
    }

    func focusLastFocusedNote() {
        guard let id = lastFocusedNoteID else {
            createNote()
            return
        }
        focusNote(documentID: id)
    }

    func menuEntries() -> [NoteMenuEntry] {
        orderedControllers().map { controller in
            NoteMenuEntry(
                id: controller.noteDocument.id,
                title: controller.noteDocument.title.isEmpty ? "Untitled" : controller.noteDocument.title,
                theme: controller.noteDocument.theme
            )
        }
    }

    var documents: [NoteDocument] {
        orderedControllers().map { $0.noteDocument }
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

    func togglePinForActiveNote() {
        guard let document = activeController()?.noteDocument else {
            return
        }
        document.pinned.toggle()
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
        let state = SavedState(
            notes: orderedControllers().map { $0.noteDocument.package() },
            trash: trash
        )
        storage.saveState(state)
    }

    var trashedNotes: [TrashedNote] {
        trash
    }

    func trashedNote(id: UUID) -> TrashedNote? {
        trash.first(where: { $0.id == id })
    }

    func restoreFromTrash(_ trashedID: UUID) {
        guard let index = trash.firstIndex(where: { $0.id == trashedID }) else { return }
        let item = trash.remove(at: index)
        createNote(item.note, activate: true, scheduleSave: true)
        saveNow()
    }

    func deletePermanently(_ trashedID: UUID) {
        trash.removeAll { $0.id == trashedID }
        saveNow()
    }

    private func appendVersion(for document: NoteDocument) {
        let version = NoteVersion(
            date: Date(),
            title: document.title,
            content: document.content,
            theme: document.theme,
            monospace: document.monospace,
            fontFamily: document.fontFamily,
            zoom: document.zoom
        )

        if let last = document.versions.last,
           last.title == version.title,
           last.content == version.content,
           last.theme == version.theme,
           last.monospace == version.monospace,
           last.fontFamily == version.fontFamily,
           last.zoom == version.zoom
        {
            return
        }

        document.versions.append(version)
        if document.versions.count > maxVersionsPerNote {
            document.versions.removeFirst(document.versions.count - maxVersionsPerNote)
        }

        scheduleSave()
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

        return orderedControllers().first
    }

    private func orderedControllers() -> [NoteWindowController] {
        orderedNoteIDs.compactMap { controllers[$0] }
    }
}

struct NoteMenuEntry {
    let id: UUID
    let title: String
    let theme: NoteTheme
}

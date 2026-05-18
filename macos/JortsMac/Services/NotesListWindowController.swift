import AppKit
import SwiftUI

final class NotesListWindowController: NSWindowController, NSWindowDelegate {
    private let manager: NoteManager
    private let onNoteSelected: (UUID) -> Void
    private var hostingController: NSHostingController<NotesListView>?

    init(
        manager: NoteManager,
        onNoteSelected: @escaping (UUID) -> Void
    ) {
        self.manager = manager
        self.onNoteSelected = onNoteSelected

        let listView = NotesListView(
            documents: manager.documents,
            onCreateNote: { manager.createNote() },
            onClose: { },
            onNoteSelected: onNoteSelected
        )

        self.hostingController = NSHostingController(rootView: listView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "All Notes - Jorts_MacOS"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.contentViewController = self.hostingController

        super.init(window: window)

        window.delegate = self
        window.center()

        updateListView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func updateListView() {
        hostingController?.rootView = NotesListView(
            documents: manager.documents,
            onCreateNote: { [weak self] in
                self?.manager.createNote()
                self?.updateListView()
            },
            onClose: { [weak self] in
                self?.close()
            },
            onNoteSelected: { [weak self] noteID in
                self?.onNoteSelected(noteID)
                DispatchQueue.main.async { [weak self] in
                    self?.close()
                }
            }
        )
    }

    func windowWillClose(_ notification: Notification) {
        window?.delegate = nil
    }
}

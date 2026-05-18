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
        window.minSize = NSSize(width: 400, height: 420)
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

    override func showWindow(_ sender: Any?) {
        applyDefaultWindowSize()
        super.showWindow(sender)
    }

    private func applyDefaultWindowSize() {
        guard let window else { return }

        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 700)
        let targetHeight = visibleFrame.height * 0.8
        let targetWidth = min(max(window.frame.width, 500), visibleFrame.width * 0.9)
        let x = visibleFrame.midX - targetWidth / 2
        let y = visibleFrame.midY - targetHeight / 2

        window.setFrame(NSRect(x: x, y: y, width: targetWidth, height: targetHeight), display: false)
    }

    func windowWillClose(_ notification: Notification) {
        window?.delegate = nil
    }
}

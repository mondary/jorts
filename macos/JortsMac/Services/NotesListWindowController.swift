import AppKit
import SwiftUI

final class NotesListWindowController: NSWindowController, NSWindowDelegate {
    private let manager: NoteManager
    private let settings: AppSettings
    private let onNoteSelected: (UUID) -> Void
    private let onShowPreferences: () -> Void
    private var trashedPreviewControllers: [UUID: NoteWindowController] = [:]
    private var hostingController: NSHostingController<NotesListView>?

    init(
        manager: NoteManager,
        settings: AppSettings,
        onShowPreferences: @escaping () -> Void,
        onNoteSelected: @escaping (UUID) -> Void
    ) {
        self.manager = manager
        self.settings = settings
        self.onNoteSelected = onNoteSelected
        self.onShowPreferences = onShowPreferences
        self.hostingController = NSHostingController(rootView: NotesListView(
            documents: manager.documents,
            trash: manager.trashedNotes,
            onCreateNote: { manager.createNote() },
            onShowPreferences: onShowPreferences,
            onOpenFinder: { NSWorkspace.shared.activateFileViewerSelecting([manager.storageURL]) },
            onNoteSelected: onNoteSelected,
            onOpenTrashed: { _ in }
        ))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "All Notes - JortsMacOS"
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
            trash: manager.trashedNotes,
            onCreateNote: { [weak self] in
                self?.manager.createNote()
                self?.updateListView()
            },
            onShowPreferences: { [weak self] in self?.onShowPreferences() },
            onOpenFinder: { [weak self] in
                guard let self else { return }
                NSWorkspace.shared.activateFileViewerSelecting([self.manager.storageURL])
            },
            onNoteSelected: { [weak self] noteID in
                self?.onNoteSelected(noteID)
                DispatchQueue.main.async { [weak self] in
                    self?.close()
                }
            },
            onOpenTrashed: { [weak self] in self?.openTrashedNote($0) }
        )
    }

    private func openTrashedNote(_ trashedID: UUID) {
        if let existing = trashedPreviewControllers[trashedID] {
            existing.showWindow(nil)
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let item = manager.trashedNote(id: trashedID) else { return }

        let document = NoteDocument(data: item.note)
        let controller = NoteWindowController(
            document: document,
            settings: settings,
            onNew: {},
            onDelete: {},
            onSave: {},
            onShowEmoji: {},
            onShowList: {},
            mode: .trash,
            onRestoreFromTrash: { [weak self] in
                self?.manager.restoreFromTrash(trashedID)
                self?.trashedPreviewControllers[trashedID]?.close()
                self?.trashedPreviewControllers.removeValue(forKey: trashedID)
                self?.updateListView()
            },
            onDeletePermanently: { [weak self] in
                self?.manager.deletePermanently(trashedID)
                self?.trashedPreviewControllers[trashedID]?.close()
                self?.trashedPreviewControllers.removeValue(forKey: trashedID)
                self?.updateListView()
            },
            onDocumentChanged: {}
        )

        trashedPreviewControllers[trashedID] = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    override func showWindow(_ sender: Any?) {
        applyDefaultWindowSize()
        super.showWindow(sender)
    }

    private func applyDefaultWindowSize() {
        guard let window else { return }

        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 700)
        let targetHeight = visibleFrame.height * 0.8
        let targetWidth = min(max(400, window.frame.width), visibleFrame.width * 0.9)
        let x = visibleFrame.midX - targetWidth / 2
        let y = visibleFrame.midY - targetHeight / 2

        window.setFrame(NSRect(x: x, y: y, width: targetWidth, height: targetHeight), display: false)
    }

    func windowWillClose(_ notification: Notification) {
        window?.delegate = nil
    }
}

import AppKit
import Combine
import SwiftUI

final class NoteWindowController: NSWindowController, NSWindowDelegate {
    let noteDocument: NoteDocument

    private let onDocumentChanged: () -> Void
    private var cancellables: Set<AnyCancellable> = []
    private var isDeleting = false

    init(
        document: NoteDocument,
        settings: AppSettings,
        onNew: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onShowEmoji: @escaping () -> Void,
        onDocumentChanged: @escaping () -> Void
    ) {
        self.noteDocument = document
        self.onDocumentChanged = onDocumentChanged

        let rootView = NoteView(
            document: document,
            settings: settings,
            onNew: onNew,
            onDelete: onDelete,
            onSave: onSave,
            onShowEmoji: onShowEmoji
        )

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: CGFloat(document.package().width),
                height: CGFloat(document.package().height)
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.title = document.windowTitle
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 240, height: 240)
        window.backgroundColor = document.theme.backgroundNSColor
        window.contentViewController = hostingController

        super.init(window: window)

        window.delegate = self
        document.onChange = { [weak self] in
            self?.syncWindowFromDocument()
            self?.onDocumentChanged()
        }

        document.$theme
            .sink { [weak window] theme in
                window?.backgroundColor = theme.backgroundNSColor
            }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func windowDidResize(_ notification: Notification) {
        guard let window else { return }
        noteDocument.size = window.frame.size
    }

    func windowDidBecomeKey(_ notification: Notification) {
        noteDocument.isFocused = true
    }

    func windowDidResignKey(_ notification: Notification) {
        noteDocument.isFocused = false
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !isDeleting else {
            return true
        }

        sender.orderOut(nil)
        onDocumentChanged()
        return false
    }

    func closeForDelete() {
        isDeleting = true
        window?.delegate = nil
        close()
    }

    private func syncWindowFromDocument() {
        window?.title = noteDocument.windowTitle
        window?.backgroundColor = noteDocument.theme.backgroundNSColor
    }
}

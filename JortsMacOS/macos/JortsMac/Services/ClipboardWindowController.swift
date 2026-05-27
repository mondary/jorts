import AppKit
import SwiftUI

final class ClipboardWindowController: NSWindowController, NSWindowDelegate {
    private let manager: NoteManager
    private let settings: AppSettings
    private let clipboard: ClipboardManager
    private var hostingController: NSHostingController<ClipboardView>?

    init(manager: NoteManager, settings: AppSettings, clipboard: ClipboardManager) {
        self.manager = manager
        self.settings = settings
        self.clipboard = clipboard

        self.hostingController = NSHostingController(rootView: ClipboardView(
            clipboard: clipboard,
            onCreateNoteFromItem: { [weak manager] item in
                manager?.createNote(prefillContent: ClipboardWindowController.noteContent(from: item))
            },
            onCopyItem: { [weak clipboard] item in clipboard?.copyToPasteboard(item) }
        ))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clipboard - JortsMacOS"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 520, height: 380)
        window.contentViewController = self.hostingController

        super.init(window: window)
        window.delegate = self
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    private static func noteContent(from item: ClipboardManager.Item) -> String {
        switch item.payload {
        case .text(let t): return t
        case .url(let u): return u.absoluteString
        case .imageData: return "[Image]"
        case .fileURLs(let urls):
            return urls.map { $0.path }.joined(separator: "\n")
        }
    }
}


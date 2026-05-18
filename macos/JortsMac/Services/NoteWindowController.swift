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
        let requestedSize = NSSize(
            width: CGFloat(document.package().width),
            height: CGFloat(document.package().height)
        )
        let requestedRect = NSRect(
            x: 0,
            y: 0,
            width: requestedSize.width,
            height: requestedSize.height
        )

        let window = NSWindow(
            contentRect: requestedRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = document.windowTitle
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 240, height: 240)
        window.backgroundColor = document.theme.backgroundNSColor
        window.contentViewController = hostingController

        if let savedPosition = document.position {
            let savedFrame = NSRect(
                x: savedPosition.x,
                y: savedPosition.y,
                width: document.size.width,
                height: document.size.height
            )
            window.setFrame(Self.constrainedFrame(savedFrame), display: false)
        } else {
            window.setContentSize(requestedSize)
            window.center()
        }

        super.init(window: window)

        window.delegate = self
        noteDocument.updateFrame(window.frame)

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
        noteDocument.updateFrame(window.frame)
    }

    func windowDidMove(_ notification: Notification) {
        guard let window else { return }
        noteDocument.updateFrame(window.frame)
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

    private static func constrainedFrame(_ frame: NSRect) -> NSRect {
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)

        if visibleFrames.contains(where: { visibleFrame in
            let intersection = visibleFrame.intersection(frame)
            return intersection.width >= 120 && intersection.height >= 120
        }) {
            return frame
        }

        guard let visibleFrame = NSScreen.main?.visibleFrame ?? visibleFrames.first else {
            return frame
        }

        let width = min(max(frame.width, 240), visibleFrame.width)
        let height = min(max(frame.height, 240), visibleFrame.height)
        let x = (visibleFrame.midX - width / 2).clamped(to: visibleFrame.minX...(visibleFrame.maxX - width))
        let y = (visibleFrame.midY - height / 2).clamped(to: visibleFrame.minY...(visibleFrame.maxY - height))

        return NSRect(x: x, y: y, width: width, height: height)
    }
}

import AppKit
import SwiftUI

private final class CommandPaletteHostingController: NSHostingController<CommandPaletteView> {
    var onCancel: (() -> Void)?
    var onMoveSelection: ((Int) -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func keyDown(with event: NSEvent) {
        // ESC
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        // Down / Up arrows
        if event.keyCode == 125 {
            onMoveSelection?(+1)
            return
        }
        if event.keyCode == 126 {
            onMoveSelection?(-1)
            return
        }
        super.keyDown(with: event)
    }
}

final class CommandPaletteWindowController: NSWindowController, NSWindowDelegate {
    private let manager: NoteManager
    private var hostingController: CommandPaletteHostingController?
    private var lastKeyWindow: NSWindow?
    private let state = CommandPaletteState()
    private var keyDownMonitor: Any?

    init(manager: NoteManager) {
        self.manager = manager
        super.init(window: nil)

        let view = makeView()
        let host = CommandPaletteHostingController(rootView: view)
        self.hostingController = host

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Command Palette"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentViewController = self.hostingController
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = true

        self.window = window
        window.delegate = self
        positionWindow()

        updateViewCallbacks()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func refreshDocuments() {
        updateViewCallbacks()
    }

    override func showWindow(_ sender: Any?) {
        refreshDocuments()
        lastKeyWindow = NSApp.keyWindow
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        positionWindow()
        NSApp.activate(ignoringOtherApps: true)
        installKeyDownMonitorIfNeeded()
    }

    override func close() {
        uninstallKeyDownMonitorIfNeeded()
        super.close()
        lastKeyWindow?.makeKeyAndOrderFront(nil)
    }

    private func makeView() -> CommandPaletteView {
        CommandPaletteView(
            documents: manager.documents,
            onOpenNote: { [weak self] id in
                self?.manager.focusNote(documentID: id)
                DispatchQueue.main.async { [weak self] in
                    self?.close()
                }
            },
            onCreateNote: { [weak self] in
                self?.manager.createNote()
            },
            onShowPreferences: {
                NSApp.sendAction(Selector(("showPreferences:")), to: nil, from: nil)
            },
            onShowAbout: {
                NSApp.sendAction(Selector(("showAbout:")), to: nil, from: nil)
            },
            onClose: { [weak self] in
                self?.close()
            },
            state: state
        )
    }

    private func updateViewCallbacks() {
        hostingController?.rootView = makeView()
        hostingController?.onCancel = { [weak self] in
            self?.close()
        }
        hostingController?.onMoveSelection = { [weak self] delta in
            self?.moveSelection(delta: delta)
        }
    }

    func windowWillClose(_ notification: Notification) {
        uninstallKeyDownMonitorIfNeeded()
    }

    private func positionWindow() {
        guard let window else { return }

        let targetScreen = lastKeyWindow?.screen ?? window.screen ?? NSScreen.main
        guard let visibleFrame = targetScreen?.visibleFrame else {
            window.center()
            return
        }

        let size = window.frame.size
        let centeredX = visibleFrame.midX - size.width / 2

        // Place the top edge ~20% down from the top of the visible screen.
        let topY = visibleFrame.maxY - visibleFrame.height * 0.20
        let originY = topY - size.height

        let x = centeredX.clamped(to: visibleFrame.minX...(visibleFrame.maxX - size.width))
        let y = originY.clamped(to: visibleFrame.minY...(visibleFrame.maxY - size.height))
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func moveSelection(delta: Int) {
        makeView().moveSelection(delta: delta)
    }

    private func installKeyDownMonitorIfNeeded() {
        guard keyDownMonitor == nil else { return }
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard
                let self,
                let window = self.window,
                window.isVisible,
                window.isKeyWindow,
                event.window === window
            else {
                return event
            }

            return event
        }
    }

    private func uninstallKeyDownMonitorIfNeeded() {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }
    }
}

import AppKit
import SwiftUI

final class ClipboardWindowController: NSWindowController, NSWindowDelegate {
    private let manager: NoteManager
    private let settings: AppSettings
    private let clipboard: ClipboardManager
    private var hostingController: NSHostingController<ClipboardView>?
    private var lastKnownVisibleFrame: NSRect?

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

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 380),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Clipboard - JortsMacOS"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .transient, .fullScreenAuxiliary]
        panel.level = .floating
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovable = false
        panel.minSize = NSSize(width: 720, height: 320)
        panel.maxSize = NSSize(width: 100000, height: 520)
        panel.contentViewController = self.hostingController
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        super.init(window: panel)
        panel.delegate = self
    }

    required init?(coder: NSCoder) { nil }

    func toggle() {
        guard let window else { return }
        if window.isVisible {
            dismissAnimated()
        } else {
            presentAnimated()
        }
    }

    private func presentAnimated() {
        guard let window else { return }

        // Drawer behavior: anchored on a screen edge, with a short slide-in animation.
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        lastKnownVisibleFrame = visible

        let inset: CGFloat = 10
        let target = targetFrame(in: visible, inset: inset, edge: settings.clipboardDrawerEdge, current: window.frame.size)

        // Start just outside the chosen edge.
        var start = target
        start = offscreenFrame(for: target, in: visible, edge: settings.clipboardDrawerEdge)
        window.setFrame(start, display: false)

        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
            window.animator().setFrame(target, display: true)
        }
    }

    private func dismissAnimated() {
        guard let window else { return }
        let visible = window.screen?.visibleFrame ?? lastKnownVisibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)

        let end = offscreenFrame(for: window.frame, in: visible, edge: settings.clipboardDrawerEdge)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
            window.animator().setFrame(end, display: true)
        } completionHandler: {
            window.orderOut(nil)
            window.alphaValue = 1
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        // Drawer-like behavior: hide when focus leaves.
        dismissAnimated()
    }

    private func targetFrame(in visible: NSRect, inset: CGFloat, edge: ClipboardDrawerEdge, current: CGSize) -> NSRect {
        switch edge {
        case .top, .bottom:
            let width = max(640, visible.width - inset * 2)
            let height = min(max(340, current.height), min(visible.height * 0.48, 520))
            let x = visible.minX + inset
            let y: CGFloat = (edge == .top) ? (visible.maxY - inset - height) : (visible.minY + inset)
            return NSRect(x: x, y: y, width: width, height: height)
        case .left, .right:
            let height = max(320, visible.height - inset * 2)
            let width = min(max(420, current.width), min(visible.width * 0.46, 720))
            let y = visible.minY + inset
            let x: CGFloat = (edge == .left) ? (visible.minX + inset) : (visible.maxX - inset - width)
            return NSRect(x: x, y: y, width: width, height: height)
        }
    }

    private func offscreenFrame(for target: NSRect, in visible: NSRect, edge: ClipboardDrawerEdge) -> NSRect {
        let pad: CGFloat = 10
        var start = target
        switch edge {
        case .bottom:
            start.origin.y = visible.minY - target.height - pad
        case .top:
            start.origin.y = visible.maxY + pad
        case .left:
            start.origin.x = visible.minX - target.width - pad
        case .right:
            start.origin.x = visible.maxX + pad
        }
        return start
    }

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

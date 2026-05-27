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

        // We want it to behave like a drawer: bottom anchored, centered, quick slide up.
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        lastKnownVisibleFrame = visible

        // Full width drawer (like Deck): span visible width with a small horizontal inset.
        let insetX: CGFloat = 10
        let marginBottom: CGFloat = 10
        let targetWidth = max(640, visible.width - insetX * 2)
        let targetHeight = min(max(340, window.frame.height), min(visible.height * 0.48, 520))
        let x = visible.minX + insetX
        let y = visible.minY + marginBottom
        let target = NSRect(x: x, y: y, width: targetWidth, height: targetHeight)

        // Start slightly below (off-screen-ish) then animate up.
        var start = target
        start.origin.y = visible.minY - targetHeight - 8
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

        var end = window.frame
        end.origin.y = visible.minY - end.height - 8

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

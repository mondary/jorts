import AppKit
import Carbon.HIToolbox
import SwiftUI

final class ClipboardWindowController: NSWindowController, NSWindowDelegate {
    private let manager: NoteManager
    private let settings: AppSettings
    private let clipboard: ClipboardManager
    private var hostingController: NSHostingController<ClipboardView>?
    private var lastKnownVisibleFrame: NSRect?
    private var lastFrontmostApp: NSRunningApplication?
    private weak var lastKeyWindow: NSWindow?
    private weak var lastFirstResponder: NSResponder?

    init(manager: NoteManager, settings: AppSettings, clipboard: ClipboardManager) {
        self.manager = manager
        self.settings = settings
        self.clipboard = clipboard

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

        // Hosting controller must be initialized after super.init so we can safely capture self.
        self.hostingController = NSHostingController(rootView: ClipboardView(
            clipboard: clipboard,
            notesProvider: { [weak manager] in
                (manager?.documents ?? []).map { doc in
                    ClipboardView.NoteDeckItem(
                        id: doc.id,
                        title: doc.title,
                        content: doc.content,
                        theme: doc.theme,
                        isPinned: doc.pinned,
                        updatedAt: doc.versions.first?.date ?? Date()
                    )
                }
            },
            onCreateNoteFromItem: { [weak manager] item in
                manager?.createNote(prefillContent: ClipboardWindowController.noteContent(from: item))
            },
            onOpenNote: { [weak manager] id in
                manager?.focusNote(documentID: id)
            },
            onCopyItem: { [weak clipboard] item in clipboard?.copyToPasteboard(item) },
            onDismiss: { [weak self] in self?.dismissAnimated() },
            onPaste: { [weak self] in self?.pasteActiveSelection() },
            shouldHandleKeyboard: { [weak self] in
                guard let window = self?.window else { return false }
                return window.isVisible && NSApp.isActive
            }
        ))
        panel.contentViewController = self.hostingController
    }

    required init?(coder: NSCoder) { nil }

    func toggle(targetApp: NSRunningApplication? = nil, targetWindow: NSWindow? = nil, targetResponder: NSResponder? = nil) {
        guard let window else { return }
        if window.isVisible {
            dismissAnimated()
        } else {
            // Remember the app/window that had the insertion cursor before the
            // drawer opened. This must happen before Jorts activates the panel.
            lastFrontmostApp = targetApp ?? NSWorkspace.shared.frontmostApplication
            rememberFocus(targetWindow: targetWindow, targetResponder: targetResponder, excluding: window)
            presentAnimated()
        }
    }

    private func rememberFocus(targetWindow: NSWindow?, targetResponder: NSResponder?, excluding clipboardWindow: NSWindow) {
        let keyWindow = targetWindow ?? NSApp.keyWindow
        guard let keyWindow, keyWindow !== clipboardWindow else {
            lastKeyWindow = nil
            lastFirstResponder = nil
            return
        }
        lastKeyWindow = keyWindow
        lastFirstResponder = targetResponder ?? keyWindow.firstResponder
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
        window.makeFirstResponder(nil)

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

    func pasteActiveSelection() {
        // Try to paste into the app that was active before the drawer opened.
        guard let app = lastFrontmostApp else {
            dismissAnimated()
            return
        }

        let targetPID = app.processIdentifier
        window?.orderOut(nil)
        window?.alphaValue = 1

        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            NSApp.activate(ignoringOtherApps: true)
            restoreLastJortsFocus()
        } else {
            app.activate(options: [.activateIgnoringOtherApps])
        }

        // Activation is asynchronous. If Cmd+V is posted immediately, it can land
        // in the drawer search field instead of the app that had focus before.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            guard let self else { return }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier != targetPID {
                app.activate(options: [.activateIgnoringOtherApps])
            }
            if app.bundleIdentifier == Bundle.main.bundleIdentifier {
                self.restoreLastJortsFocus()
                self.postCommandV()
            } else {
                self.postCommandV(to: targetPID)
            }
        }
    }

    private func restoreLastJortsFocus() {
        guard let lastKeyWindow else { return }
        lastKeyWindow.makeKeyAndOrderFront(nil)
        if let responder = lastFirstResponder {
            lastKeyWindow.makeFirstResponder(responder)
        }
    }

    private func postCommandV() {
        // Best-effort: simulate Cmd+V. This typically requires Accessibility permission.
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        vDown?.flags = CGEventFlags.maskCommand
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        vUp?.flags = CGEventFlags.maskCommand

        vDown?.post(tap: CGEventTapLocation.cghidEventTap)
        vUp?.post(tap: CGEventTapLocation.cghidEventTap)
    }

    private func postCommandV(to pid: pid_t) {
        // For external target apps, posting directly to PID is more reliable.
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        vDown?.flags = CGEventFlags.maskCommand
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        vUp?.flags = CGEventFlags.maskCommand

        guard pid > 0 else {
            postCommandV()
            return
        }
        vDown?.postToPid(pid)
        vUp?.postToPid(pid)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Drawer-like behavior: hide when focus leaves.
        dismissAnimated()
    }

    private func targetFrame(in visible: NSRect, inset: CGFloat, edge: ClipboardDrawerEdge, current: CGSize) -> NSRect {
        switch edge {
        case .top, .bottom:
            let width = max(640, visible.width - inset * 2)
            let height = min(max(340, current.height), min(visible.height * 0.46, 520))
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
        case .colorHex(let hex):
            return hex
        }
    }
}

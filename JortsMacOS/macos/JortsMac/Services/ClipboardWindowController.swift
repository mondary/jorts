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
    private weak var anchorWindow: NSWindow?
    private var keyMonitor: Any?
    private var isClipboardViewAtDefaultContext = true

    init(manager: NoteManager, settings: AppSettings, clipboard: ClipboardManager) {
        self.manager = manager
        self.settings = settings
        self.clipboard = clipboard

        let panel = ClipboardDrawerPanel(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 380),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.title = "Clipboard - JortsMacOS"
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .transient, .fullScreenAuxiliary]
        panel.level = .floating
        panel.isMovable = false
        panel.minSize = NSSize(width: 720, height: 320)
        panel.maxSize = NSSize(width: 100000, height: 520)
        panel.contentViewController = self.hostingController
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        super.init(window: panel)
        panel.delegate = self
        panel.onEscapePressed = { [weak self] in
            self?.handleEscapeRequest()
        }
        installKeyMonitor()

        // Hosting controller must be initialized after super.init so we can safely capture self.
        self.hostingController = NSHostingController(rootView: makeClipboardView())
        panel.contentViewController = self.hostingController
    }

    private func makeClipboardView() -> ClipboardView {
        ClipboardView(
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
            },
            onContextStateChanged: { [weak self] isDefaultContext in
                self?.isClipboardViewAtDefaultContext = isDefaultContext
            }
        )
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self,
                  let window = self.window,
                  window.isVisible,
                  event.keyCode == 53
            else {
                return event
            }
            self.handleEscapeRequest()
            return nil
        }
    }

    private func handleEscapeRequest() {
        guard window?.isVisible == true else { return }
        if isClipboardViewAtDefaultContext {
            dismissAnimated()
        } else {
            clipboard.markDrawerPresented()
        }
    }

    private func rebuildContentView() {
        hostingController = NSHostingController(rootView: makeClipboardView())
        window?.contentViewController = hostingController
    }

    func toggle(targetApp: NSRunningApplication? = nil, targetWindow: NSWindow? = nil, targetResponder: NSResponder? = nil) {
        guard let window else { return }
        if window.isVisible {
            dismissAnimated()
        } else {
            // Remember the app/window that had the insertion cursor before the
            // drawer opened. This must happen before Jorts activates the panel.
            lastFrontmostApp = targetApp ?? NSWorkspace.shared.frontmostApplication
            anchorWindow = targetWindow
            rememberFocus(targetWindow: targetWindow, targetResponder: targetResponder, excluding: window)
            isClipboardViewAtDefaultContext = true
            rebuildContentView()
            clipboard.markDrawerPresented()
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
        let visible = preferredVisibleFrame(fallbackWindow: window)
        let layoutBounds = preferredLayoutBounds(fallbackWindow: window, visibleFrame: visible, edge: settings.clipboardDrawerEdge)
        lastKnownVisibleFrame = layoutBounds

        let inset: CGFloat = 0
        let target = targetFrame(in: layoutBounds, inset: inset, edge: settings.clipboardDrawerEdge, current: window.frame.size)

        // Start just outside the chosen edge.
        var start = target
        start = offscreenFrame(for: target, in: layoutBounds, edge: settings.clipboardDrawerEdge)
        window.setFrame(start, display: false)

        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(nil)

        // Two-step motion for a "dynamic island" feel: fast approach + tiny settle.
        let overshoot = overshootFrame(for: target, edge: settings.clipboardDrawerEdge)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.10
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.15, 1.05, 0.2, 1.0)
            window.animator().alphaValue = 1
            window.animator().setFrame(overshoot, display: true)
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.0, 0.15, 1.0)
                window.animator().setFrame(target, display: true)
            }
        }
    }

    private func preferredVisibleFrame(fallbackWindow: NSWindow) -> NSRect {
        if let targetVisible = anchorWindow?.screen?.visibleFrame {
            return targetVisible
        }

        let mouseLocation = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return mouseScreen.visibleFrame
        }

        return fallbackWindow.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
    }

    private func preferredLayoutBounds(fallbackWindow: NSWindow, visibleFrame: NSRect, edge: ClipboardDrawerEdge) -> NSRect {
        guard edge == .top else { return visibleFrame }
        if let screenFrame = anchorWindow?.screen?.frame {
            return screenFrame
        }
        let mouseLocation = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return mouseScreen.frame
        }
        return fallbackWindow.screen?.frame ?? visibleFrame
    }

    private func dismissAnimated() {
        guard let window else { return }
        clipboard.markDrawerPresented()
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
            app.unhide()
            app.activate(options: [.activateIgnoringOtherApps])
        }

        // Activation is asynchronous. If Cmd+V is posted immediately, it can land
        // in the drawer search field instead of the app that had focus before.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
            guard let self else { return }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier != targetPID {
                app.unhide()
                app.activate(options: [.activateIgnoringOtherApps])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                    self?.pasteIntoActivatedTarget(app: app, targetPID: targetPID)
                }
                return
            }
            self.pasteIntoActivatedTarget(app: app, targetPID: targetPID)
        }
    }

    private func pasteIntoActivatedTarget(app: NSRunningApplication, targetPID: pid_t) {
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != targetPID {
            app.unhide()
            app.activate(options: [.activateIgnoringOtherApps])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            if app.bundleIdentifier == Bundle.main.bundleIdentifier {
                self.restoreLastJortsFocus()
            } else {
                // Browser/web apps such as Gmail usually require a normal HID
                // Cmd+V after the app is frontmost; posting directly to PID can
                // miss the focused web view.
            }
            self.postCommandV()
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

    @objc func windowDidResignKey(_ notification: Notification) {
        guard window?.isVisible == true else { return }
        dismissAnimated()
    }

    private func targetFrame(in visible: NSRect, inset: CGFloat, edge: ClipboardDrawerEdge, current: CGSize) -> NSRect {
        switch edge {
        case .top, .bottom:
            let width = visible.width - inset * 2
            let reducedHeight = current.height * 0.70
            let height = min(max(280, reducedHeight), min(visible.height * 0.52, 560))
            let x = visible.minX + inset
            let y: CGFloat = (edge == .top) ? (visible.maxY - height) : (visible.minY + inset)
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

    private func overshootFrame(for target: NSRect, edge: ClipboardDrawerEdge) -> NSRect {
        let delta: CGFloat = 16
        var frame = target
        switch edge {
        case .top:
            frame.origin.y -= delta
        case .bottom:
            frame.origin.y += delta
        case .left:
            frame.origin.x += delta
        case .right:
            frame.origin.x -= delta
        }
        return frame
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

private final class ClipboardDrawerPanel: NSPanel {
    var onEscapePressed: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscapePressed?()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscapePressed?()
    }
}

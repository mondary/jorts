import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private let onLanguageChanged: () -> Void

    init(settings: AppSettings, storageURL: URL, onLanguageChanged: @escaping () -> Void) {
        self.onLanguageChanged = onLanguageChanged

        let rootView = PreferencesView(
            settings: settings,
            storageURL: storageURL,
            onClose: {},
            onLanguageChanged: onLanguageChanged
        )

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Preferences - PKbrain"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        window.delegate = self
        hostingController.rootView = PreferencesView(
            settings: settings,
            storageURL: storageURL,
            onClose: { [weak window] in window?.orderOut(nil) },
            onLanguageChanged: onLanguageChanged
        )
    }

    required init?(coder: NSCoder) {
        nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

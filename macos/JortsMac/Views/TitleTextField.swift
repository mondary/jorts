import AppKit
import SwiftUI

struct TitleTextField: NSViewRepresentable {
    @Binding var text: String
    let font: NSFont
    let textColor: NSColor
    let onTabToEditor: () -> Void
    let isNewNote: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = font
        field.textColor = textColor
        field.alignment = .center
        field.delegate = context.coordinator
        field.maximumNumberOfLines = 1
        field.lineBreakMode = .byTruncatingTail
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.font = font
        nsView.textColor = textColor
        nsView.alignment = .center
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TitleTextField
        private var hasFocusedOnce = false

        init(_ parent: TitleTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                parent.onTabToEditor()
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) || commandSelector == #selector(NSResponder.insertLineBreak(_:)) {
                parent.onTabToEditor()
                return true
            }
            return false
        }

        func controlDidBecomeEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }

            // Only apply custom focus behavior on first focus
            guard !hasFocusedOnce else {
                return
            }
            hasFocusedOnce = true

            if parent.isNewNote {
                // New note: select all text for easy replacement
                field.selectText(nil)
            } else {
                // Existing note: move cursor to end
                field.currentEditor()?.selectedRange = NSRange(location: field.stringValue.count, length: 0)
            }
        }
    }
}

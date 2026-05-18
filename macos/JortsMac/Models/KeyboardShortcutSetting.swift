import AppKit
import Foundation

enum ShortcutModifierPreset: String, CaseIterable, Codable, Identifiable {
    case command
    case commandShift
    case commandOption
    case commandControl
    case commandOptionShift

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .command: "Command"
        case .commandShift: "Command + Shift"
        case .commandOption: "Command + Option"
        case .commandControl: "Command + Control"
        case .commandOptionShift: "Command + Option + Shift"
        }
    }

    var symbolPrefix: String {
        switch self {
        case .command: "⌘"
        case .commandShift: "⇧⌘"
        case .commandOption: "⌥⌘"
        case .commandControl: "⌃⌘"
        case .commandOptionShift: "⌥⇧⌘"
        }
    }

    var flags: NSEvent.ModifierFlags {
        switch self {
        case .command: [.command]
        case .commandShift: [.command, .shift]
        case .commandOption: [.command, .option]
        case .commandControl: [.command, .control]
        case .commandOptionShift: [.command, .option, .shift]
        }
    }
}

struct KeyboardShortcutSetting: Codable, Equatable {
    var key: String
    var modifier: ShortcutModifierPreset

    var normalizedKey: String {
        switch key {
        case "delete": "\u{8}"
        case "space": " "
        default: key.lowercased()
        }
    }

    var displayValue: String {
        let label: String
        switch normalizedKey {
        case "\u{8}": label = "⌫"
        case " ": label = "Space"
        default: label = normalizedKey.uppercased()
        }
        return "\(modifier.symbolPrefix)\(label)"
    }
}

enum ShortcutAction: String, CaseIterable, Identifiable {
    case newStickyNote
    case showAllNotes
    case showNotesList
    case saveAllNotes
    case preferences
    case closeNoteWindow
    case deleteStickyNote
    case toggleList
    case emojiSymbols
    case toggleMonospace
    case zoomIn
    case zoomOut
    case actualSize

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newStickyNote: "New Sticky Note"
        case .showAllNotes: "Show All Notes"
        case .showNotesList: "Show Notes List"
        case .saveAllNotes: "Save All Notes"
        case .preferences: "Preferences"
        case .closeNoteWindow: "Close Note Window"
        case .deleteStickyNote: "Delete Sticky Note"
        case .toggleList: "Toggle List"
        case .emojiSymbols: "Emoji & Symbols"
        case .toggleMonospace: "Toggle Monospace"
        case .zoomIn: "Zoom In"
        case .zoomOut: "Zoom Out"
        case .actualSize: "Actual Size"
        }
    }

    var group: String {
        switch self {
        case .newStickyNote, .showAllNotes, .showNotesList, .saveAllNotes, .preferences:
            "App"
        case .closeNoteWindow, .deleteStickyNote, .toggleList, .emojiSymbols, .toggleMonospace, .zoomIn, .zoomOut, .actualSize:
            "Note"
        }
    }

    var defaultShortcut: KeyboardShortcutSetting {
        switch self {
        case .newStickyNote: KeyboardShortcutSetting(key: "n", modifier: .command)
        case .showAllNotes: KeyboardShortcutSetting(key: "l", modifier: .command)
        case .showNotesList: KeyboardShortcutSetting(key: "l", modifier: .commandOption)
        case .saveAllNotes: KeyboardShortcutSetting(key: "s", modifier: .command)
        case .preferences: KeyboardShortcutSetting(key: ",", modifier: .command)
        case .closeNoteWindow: KeyboardShortcutSetting(key: "w", modifier: .command)
        case .deleteStickyNote: KeyboardShortcutSetting(key: "delete", modifier: .command)
        case .toggleList: KeyboardShortcutSetting(key: "l", modifier: .commandShift)
        case .emojiSymbols: KeyboardShortcutSetting(key: "space", modifier: .commandControl)
        case .toggleMonospace: KeyboardShortcutSetting(key: "m", modifier: .command)
        case .zoomIn: KeyboardShortcutSetting(key: "+", modifier: .command)
        case .zoomOut: KeyboardShortcutSetting(key: "-", modifier: .command)
        case .actualSize: KeyboardShortcutSetting(key: "0", modifier: .command)
        }
    }
}

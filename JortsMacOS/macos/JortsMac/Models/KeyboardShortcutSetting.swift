import AppKit
import Carbon.HIToolbox
import Foundation

enum ShortcutModifierPreset: String, CaseIterable, Codable, Identifiable {
    case shift
    case controlShift
    case command
    case commandShift
    case commandOption
    case commandControl
    case commandOptionShift

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shift: localizedString("modifier_shift")
        case .controlShift: localizedString("modifier_control_shift")
        case .command: localizedString("modifier_command")
        case .commandShift: localizedString("modifier_command_shift")
        case .commandOption: localizedString("modifier_command_option")
        case .commandControl: localizedString("modifier_command_control")
        case .commandOptionShift: localizedString("modifier_command_option_shift")
        }
    }

    var symbolPrefix: String {
        switch self {
        case .shift: "⇧"
        case .controlShift: "⌃⇧"
        case .command: "⌘"
        case .commandShift: "⇧⌘"
        case .commandOption: "⌥⌘"
        case .commandControl: "⌃⌘"
        case .commandOptionShift: "⌥⇧⌘"
        }
    }

    var flags: NSEvent.ModifierFlags {
        switch self {
        case .shift: [.shift]
        case .controlShift: [.control, .shift]
        case .command: [.command]
        case .commandShift: [.command, .shift]
        case .commandOption: [.command, .option]
        case .commandControl: [.command, .control]
        case .commandOptionShift: [.command, .option, .shift]
        }
    }

    var carbonFlags: UInt32 {
        switch self {
        case .shift: return UInt32(shiftKey)
        case .controlShift: return UInt32(controlKey | shiftKey)
        case .command: return UInt32(cmdKey)
        case .commandShift: return UInt32(cmdKey | shiftKey)
        case .commandOption: return UInt32(cmdKey | optionKey)
        case .commandControl: return UInt32(cmdKey | controlKey)
        case .commandOptionShift: return UInt32(cmdKey | optionKey | shiftKey)
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
    case focusLastNoteGlobal
    case newNoteGlobal
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
        case .focusLastNoteGlobal: localizedString("shortcut_focus_last_note_global")
        case .newNoteGlobal: localizedString("shortcut_create_new_note_global")
        case .newStickyNote: localizedString("new_sticky_note")
        case .showAllNotes: localizedString("show_all_notes")
        case .showNotesList: localizedString("show_notes_list")
        case .saveAllNotes: localizedString("save_all_notes")
        case .preferences: localizedString("preferences")
        case .closeNoteWindow: localizedString("close_note_window")
        case .deleteStickyNote: localizedString("delete_sticky_note")
        case .toggleList: localizedString("toggle_list")
        case .emojiSymbols: localizedString("emoji_symbols")
        case .toggleMonospace: localizedString("toggle_monospace")
        case .zoomIn: localizedString("zoom_in")
        case .zoomOut: localizedString("zoom_out")
        case .actualSize: localizedString("actual_size")
        }
    }

    var group: String {
        switch self {
        case .focusLastNoteGlobal, .newNoteGlobal, .newStickyNote, .showAllNotes, .showNotesList, .saveAllNotes, .preferences:
            localizedString("shortcut_group_app")
        case .closeNoteWindow, .deleteStickyNote, .toggleList, .emojiSymbols, .toggleMonospace, .zoomIn, .zoomOut, .actualSize:
            localizedString("shortcut_group_note")
        }
    }

    var defaultShortcut: KeyboardShortcutSetting {
        switch self {
        // Avoid Shift+Space: too easy to trigger while typing.
        // Keep global shortcuts close to each other without conflicting with common macOS shortcuts.
        // Cmd+Shift+Space: focus last note
        // Ctrl+Shift+Space: create new note
        case .focusLastNoteGlobal: KeyboardShortcutSetting(key: "space", modifier: .commandShift)
        case .newNoteGlobal: KeyboardShortcutSetting(key: "space", modifier: .controlShift)
        case .newStickyNote: KeyboardShortcutSetting(key: "n", modifier: .command)
        case .showAllNotes: KeyboardShortcutSetting(key: "l", modifier: .shift)
        case .showNotesList: KeyboardShortcutSetting(key: "l", modifier: .commandShift)
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

import SwiftUI

struct ShortcutsPreferencesView: View {
    @ObservedObject var settings: AppSettings

    private var appActions: [ShortcutAction] {
        ShortcutAction.allCases.filter { $0.group == "App" }
    }

    private var noteActions: [ShortcutAction] {
        ShortcutAction.allCases.filter { $0.group == "Note" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                shortcutSection("App", actions: appActions)
                shortcutSection("Note", actions: noteActions)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func shortcutSection(_ title: String, actions: [ShortcutAction]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(actions) { action in
                    ShortcutRow(settings: settings, action: action)
                    if action != actions.last {
                        Divider()
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct ShortcutRow: View {
    @ObservedObject var settings: AppSettings
    let action: ShortcutAction

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(action.title)
                    .font(.body)
                Text(settings.shortcut(for: action).displayValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: modifierBinding) {
                ForEach(ShortcutModifierPreset.allCases) { modifier in
                    Text(modifier.displayName).tag(modifier)
                }
            }
            .labelsHidden()
            .frame(width: 190)

            TextField("Key", text: keyBinding)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
                .frame(width: 72)

            Button("Reset") {
                settings.resetShortcut(for: action)
            }
            .frame(width: 64)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var modifierBinding: Binding<ShortcutModifierPreset> {
        Binding(
            get: { settings.shortcut(for: action).modifier },
            set: { modifier in
                var shortcut = settings.shortcut(for: action)
                shortcut.modifier = modifier
                settings.setShortcut(shortcut, for: action)
            }
        )
    }

    private var keyBinding: Binding<String> {
        Binding(
            get: { displayKey(settings.shortcut(for: action).key) },
            set: { value in
                var shortcut = settings.shortcut(for: action)
                shortcut.key = normalizedInput(value)
                settings.setShortcut(shortcut, for: action)
            }
        )
    }

    private func normalizedInput(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return settings.shortcut(for: action).key
        }

        if trimmed.lowercased() == "space" {
            return "space"
        }

        if trimmed.lowercased() == "delete" || trimmed == "⌫" {
            return "delete"
        }

        return String(trimmed.suffix(1)).lowercased()
    }

    private func displayKey(_ key: String) -> String {
        switch key {
        case "space": "Space"
        case "delete": "⌫"
        default: key.uppercased()
        }
    }
}

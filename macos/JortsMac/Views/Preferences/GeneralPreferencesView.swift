import SwiftUI

struct GeneralPreferencesView: View {
    @ObservedObject var settings: AppSettings
    let storageURL: URL
    let onRestartRequested: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Language Section
            VStack(alignment: .leading, spacing: 8) {
                Text(localizedString("language"))
                    .font(.headline)

                Picker("", selection: $settings.selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            // Storage Section
            VStack(alignment: .leading, spacing: 8) {
                Text(localizedString("storage"))
                    .font(.headline)

                VStack(alignment: .leading, spacing: 10) {
                    Text(storageURL.deletingLastPathComponent().path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .textSelection(.enabled)

                    HStack {
                        Button("Change…") {
                            chooseStorageDirectory()
                        }

                        Spacer()

                        Text("Restart required")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("New Notes")
                    .font(.headline)

                Toggle("Randomize new note position", isOn: $settings.randomizeNewNotePosition)
                    .toggleStyle(.switch)

                Text("When enabled, new notes appear at a slightly random position instead of always centered.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Typing Effects")
                    .font(.headline)

                Picker("Effect", selection: $settings.typingEffect) {
                    ForEach(TypingEffect.allCases) { effect in
                        Text(effect.displayName).tag(effect)
                    }
                }
                .pickerStyle(.segmented)

                Text("Adds a visual effect for each typed character.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Import/Export
            VStack(alignment: .leading, spacing: 10) {
                Text("Import / Export")
                    .font(.headline)

                HStack(spacing: 10) {
                    Button("Export…") { exportNotes() }
                    Button("Import…") { importNotes() }
                    Spacer()
                }

                Text("Import replaces your current notes file and requires a restart.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func chooseStorageDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            return
        }

        settings.storageDirectoryPath = url.path
        onRestartRequested()
    }

    private func exportNotes() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "jorts_saved_state.json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            try data.write(to: destinationURL, options: [.atomic])
        } catch {
            NSLog("JortsMac: failed to export notes: \(error)")
        }
    }

    private func importNotes() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let sourceURL = panel.url else {
            return
        }

        do {
            let data = try Data(contentsOf: sourceURL)

            // Basic sanity check: ensure it decodes as [NoteData]
            _ = try JSONDecoder().decode([NoteData].self, from: data)

            let fm = FileManager.default
            try fm.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            if fm.fileExists(atPath: storageURL.path) {
                let backupURL = storageURL.deletingLastPathComponent()
                    .appendingPathComponent("saved_state.backup.json")
                try? fm.removeItem(at: backupURL)
                try fm.copyItem(at: storageURL, to: backupURL)
            }

            try data.write(to: storageURL, options: [.atomic])
            onRestartRequested()
        } catch {
            NSLog("JortsMac: failed to import notes: \(error)")
        }
    }
}

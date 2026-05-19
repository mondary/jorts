import AppKit
import SwiftUI

struct GeneralPreferencesView: View {
    @ObservedObject var settings: AppSettings
    let storageURL: URL
    let onRestartRequested: () -> Void

    var body: some View {
        ScrollView {
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

            VStack(alignment: .leading, spacing: 10) {
                Text("Inline Calculations")
                    .font(.headline)

                Toggle("Show results while typing", isOn: $settings.inlineCalculations)
                    .toggleStyle(.switch)

                Text("Shows simple math results in a subtle right-side column (Numi-style).")
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

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Cleanup")
                    .font(.headline)

                Button("Archive Duplicates / Backups…") {
                    archiveDuplicatesAndBackups()
                }

                Text("Moves `Notes/Duplicates`, `Trash/Duplicates`, and `saved_state` backup files into an Archive folder (safe cleanup).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            }
            .padding(24)
        }
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

    private func archiveDuplicatesAndBackups() {
        let storageDir = storageURL.deletingLastPathComponent()
        let candidates: [URL] = [
            storageDir.appendingPathComponent("Notes/Duplicates", isDirectory: true),
            storageDir.appendingPathComponent("Trash/Duplicates", isDirectory: true),
            storageDir.appendingPathComponent("saved_state.json.bak"),
            storageDir.appendingPathComponent("saved_state.backup.json")
        ]

        let existing = candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Nothing to archive"
            alert.informativeText = "No Duplicates folders or backup files were found."
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Archive duplicates and backups?"
        alert.informativeText = "This will move Duplicates folders and saved_state backup files into an Archive folder inside your storage directory."
        alert.addButton(withTitle: "Archive")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let fm = FileManager.default
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let archiveDir = storageDir
            .appendingPathComponent("Archive", isDirectory: true)
            .appendingPathComponent("Cleanup-\(stamp)", isDirectory: true)
        do {
            try fm.createDirectory(at: archiveDir, withIntermediateDirectories: true)

            for src in existing {
                let target = archiveDir.appendingPathComponent(src.lastPathComponent, isDirectory: src.hasDirectoryPath)
                try? fm.removeItem(at: target)
                try fm.moveItem(at: src, to: target)
            }

            let done = NSAlert()
            done.messageText = "Archive created"
            done.informativeText = archiveDir.path
            done.runModal()
        } catch {
            let failed = NSAlert()
            failed.messageText = "Archive failed"
            failed.informativeText = error.localizedDescription
            failed.runModal()
        }
    }
}

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
                        Button(localizedString("change")) {
                            chooseStorageDirectory()
                        }

                        Spacer()

                        Text(localizedString("restart_required"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(localizedString("new_notes"))
                    .font(.headline)

                Toggle(localizedString("randomize_new_note_position"), isOn: $settings.randomizeNewNotePosition)
                    .toggleStyle(.switch)

                Text(localizedString("randomize_new_note_position_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(localizedString("typing_effects"))
                    .font(.headline)

                Picker(localizedString("effect"), selection: $settings.typingEffect) {
                    ForEach(TypingEffect.allCases) { effect in
                        Text(effect.displayName).tag(effect)
                    }
                }
                .pickerStyle(.segmented)

                Text(localizedString("typing_effects_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(localizedString("inline_calculations"))
                    .font(.headline)

                Toggle(localizedString("show_results_while_typing"), isOn: $settings.inlineCalculations)
                    .toggleStyle(.switch)
                Toggle(localizedString("show_brand_icons_while_typing"), isOn: $settings.inlineBrandIcons)
                    .toggleStyle(.switch)

                Text(localizedString("inline_calculations_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(localizedString("clipboard"))
                    .font(.headline)

                Picker(localizedString("position"), selection: $settings.clipboardDrawerEdge) {
                    Text(localizedString("position_top")).tag(ClipboardDrawerEdge.top)
                    Text(localizedString("position_bottom")).tag(ClipboardDrawerEdge.bottom)
                    Text(localizedString("position_left")).tag(ClipboardDrawerEdge.left)
                    Text(localizedString("position_right")).tag(ClipboardDrawerEdge.right)
                }
                .pickerStyle(.segmented)

                Text(localizedString("clipboard_position_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Import/Export
            VStack(alignment: .leading, spacing: 10) {
                Text(localizedString("import_export"))
                    .font(.headline)

                HStack(spacing: 10) {
                    Button(localizedString("export")) { exportNotes() }
                    Button(localizedString("import")) { importNotes() }
                    Spacer()
                }

                Text(localizedString("import_export_hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(localizedString("cleanup"))
                    .font(.headline)

                Button(localizedString("archive_duplicates_backups")) {
                    archiveDuplicatesAndBackups()
                }

                Text(localizedString("archive_duplicates_backups_hint"))
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
        panel.prompt = localizedString("choose")

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
            NSLog("PKbrain: failed to export notes: \(error)")
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
            NSLog("PKbrain: failed to import notes: \(error)")
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

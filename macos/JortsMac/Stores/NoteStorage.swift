import Foundation

final class NoteStorage {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    let storageURL: URL
    private let notesDirectory: URL
    private let trashDirectory: URL

    init(storageDirectoryOverride: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()

        let applicationSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let baseDirectory = storageDirectoryOverride ?? (applicationSupport ?? fileManager.homeDirectoryForCurrentUser)
        let storageDirectory = baseDirectory
            .appendingPathComponent("JortsMacOS", isDirectory: true)
        storageURL = storageDirectory.appendingPathComponent("saved_state.json")
        notesDirectory = storageDirectory.appendingPathComponent("Notes", isDirectory: true)
        trashDirectory = storageDirectory.appendingPathComponent("Trash", isDirectory: true)
        prepareStorageDirectory(storageDirectory)
        prepareStorageDirectory(notesDirectory)
        prepareStorageDirectory(trashDirectory)
        importLegacySaveIfNeeded(to: storageURL)
    }

    func loadState() -> SavedState {
        // Preferred format: one Markdown file per note.
        if let state = loadFromMarkdownFiles() {
            return state
        }

        // Fallback: legacy JSON.
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return SavedState()
        }

        do {
            let data = try Data(contentsOf: storageURL)
            if let state = try? decoder.decode(SavedState.self, from: data) {
                return state
            }
            let notes = try decoder.decode([NoteData].self, from: data)
            return SavedState(notes: notes, trash: [])
        } catch {
            NSLog("JortsMac: failed to load notes from \(storageURL.path): \(error)")
            return SavedState()
        }
    }

    func saveState(_ state: SavedState) {
        // Write the new format first (per-note Markdown).
        do {
            try saveToMarkdownFiles(state)
        } catch {
            NSLog("JortsMac: failed to save notes as Markdown files: \(error)")
        }

        // Also keep a JSON snapshot for backwards-compat import/export.
        do {
            let data = try encoder.encode(state)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            NSLog("JortsMac: failed to save notes to \(storageURL.path): \(error)")
        }
    }

    private func loadFromMarkdownFiles() -> SavedState? {
        guard fileManager.fileExists(atPath: notesDirectory.path) else { return nil }

        do {
            let noteFiles = (try fileManager.contentsOfDirectory(at: notesDirectory, includingPropertiesForKeys: nil))
                .filter { $0.pathExtension.lowercased() == "md" }
            let trashFiles = (try fileManager.contentsOfDirectory(at: trashDirectory, includingPropertiesForKeys: nil))
                .filter { $0.pathExtension.lowercased() == "md" }

            guard !noteFiles.isEmpty || !trashFiles.isEmpty else {
                return nil
            }

            let notes: [NoteData] = noteFiles.compactMap { url in
                do { return try readNoteMarkdown(from: url) } catch { return nil }
            }

            let trash: [TrashedNote] = trashFiles.compactMap { url in
                do { return try readTrashedMarkdown(from: url) } catch { return nil }
            }

            return SavedState(notes: notes, trash: trash.sorted { $0.deletedAt > $1.deletedAt })
        } catch {
            NSLog("JortsMac: failed to load Markdown notes: \(error)")
            return nil
        }
    }

    private func saveToMarkdownFiles(_ state: SavedState) throws {
        // Notes
        for note in state.notes {
            let url = notesDirectory.appendingPathComponent("\(note.id.uuidString).md")
            let text = serialize(note: note)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }

        // Trash
        for trashed in state.trash {
            let url = trashDirectory.appendingPathComponent("\(trashed.id.uuidString).md")
            let text = serialize(trashed: trashed)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func readNoteMarkdown(from url: URL) throws -> NoteData {
        let content = try String(contentsOf: url, encoding: .utf8)
        let (frontMatter, body) = parseFrontMatter(content)
        return decodeNote(frontMatter: frontMatter, body: body)
    }

    private func readTrashedMarkdown(from url: URL) throws -> TrashedNote {
        let content = try String(contentsOf: url, encoding: .utf8)
        let (frontMatter, body) = parseFrontMatter(content)
        let note = decodeNote(frontMatter: frontMatter, body: body)
        let deletedAt = decodeDate(frontMatter["deletedAt"]) ?? Date()
        return TrashedNote(note: note, deletedAt: deletedAt)
    }

    private func serialize(note: NoteData, extraFrontMatter: [String: String] = [:]) -> String {
        var lines: [String] = []
        lines.append("---")
        lines.append("id: \(note.id.uuidString)")
        lines.append("title: \(escape(note.title))")
        lines.append("theme: \(note.theme.rawValue)")
        lines.append("monospace: \(note.monospace)")
        lines.append("fontFamily: \(escape(note.fontFamily.rawValue))")
        lines.append("zoom: \(note.zoom)")
        lines.append("width: \(note.width)")
        lines.append("height: \(note.height)")
        if let x = note.x { lines.append("x: \(x)") }
        if let y = note.y { lines.append("y: \(y)") }
        lines.append("macFrameVersion: \(note.macFrameVersion)")
        for (k, v) in extraFrontMatter {
            lines.append("\(k): \(escape(v))")
        }
        lines.append("---")
        lines.append("")
        lines.append(note.content)
        if !note.content.hasSuffix("\n") { lines.append("") }
        return lines.joined(separator: "\n")
    }

    private func serialize(trashed: TrashedNote) -> String {
        serialize(note: trashed.note, extraFrontMatter: ["deletedAt": encodeDate(trashed.deletedAt)])
    }

    private func parseFrontMatter(_ input: String) -> ([String: String], String) {
        guard input.hasPrefix("---\n") else { return ([:], input) }
        guard let endRange = input.range(of: "\n---\n", options: [], range: input.index(input.startIndex, offsetBy: 4)..<input.endIndex) else {
            return ([:], input)
        }
        let fmBlock = String(input[input.index(input.startIndex, offsetBy: 4)..<endRange.lowerBound])
        let body = String(input[endRange.upperBound...])

        var dict: [String: String] = [:]
        for line in fmBlock.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            dict[key] = unescape(value)
        }

        return (dict, body)
    }

    private func decodeNote(frontMatter: [String: String], body: String) -> NoteData {
        var note = NoteData(
            title: frontMatter["title"] ?? "",
            theme: NoteTheme(rawValue: Int(frontMatter["theme"] ?? "") ?? NoteTheme.blueberry.rawValue) ?? .blueberry,
            content: body,
            monospace: parseBool(frontMatter["monospace"]) ?? false,
            fontFamily: FontFamily(rawValue: frontMatter["fontFamily"] ?? FontFamily.system.rawValue) ?? .system,
            zoom: Int(frontMatter["zoom"] ?? "") ?? NoteData.defaultZoom,
            width: Int(frontMatter["width"] ?? "") ?? NoteData.defaultWidth,
            height: Int(frontMatter["height"] ?? "") ?? NoteData.defaultHeight,
            x: Double(frontMatter["x"] ?? ""),
            y: Double(frontMatter["y"] ?? ""),
            macFrameVersion: Int(frontMatter["macFrameVersion"] ?? "") ?? NoteData.currentMacFrameVersion,
            versions: [] // versions stay in JSON for now
        )
        if let idString = frontMatter["id"], let id = UUID(uuidString: idString) {
            note.id = id
        }
        return note
    }

    private func parseBool(_ raw: String?) -> Bool? {
        guard let raw else { return nil }
        switch raw.lowercased() {
        case "true", "1", "yes", "y": return true
        case "false", "0", "no", "n": return false
        default: return nil
        }
    }

    private func encodeDate(_ date: Date) -> String {
        String(date.timeIntervalSinceReferenceDate)
    }

    private func decodeDate(_ raw: String?) -> Date? {
        guard let raw, let t = TimeInterval(raw) else { return nil }
        return Date(timeIntervalSinceReferenceDate: t)
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: "\\n")
    }

    private func unescape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\n", with: "\n")
    }

    private func prepareStorageDirectory(_ directory: URL) {
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            NSLog("JortsMac: failed to create storage directory \(directory.path): \(error)")
        }
    }

    private func importLegacySaveIfNeeded(to destinationURL: URL) {
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            return
        }

        for candidate in legacySaveCandidates() where fileManager.fileExists(atPath: candidate.path) {
            do {
                try fileManager.copyItem(at: candidate, to: destinationURL)
                NSLog("JortsMac: imported legacy Jorts save from \(candidate.path)")
                return
            } catch {
                NSLog("JortsMac: failed to import legacy save \(candidate.path): \(error)")
            }
        }
    }

    private func legacySaveCandidates() -> [URL] {
        let home = fileManager.homeDirectoryForCurrentUser
        let applicationSupport = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )) ?? home

        return [
            applicationSupport.appendingPathComponent("io.github.elly_code.jorts/saved_state.json"),
            applicationSupport.appendingPathComponent("io.github.ellie_commons.jorts/saved_state.json"),
            home.appendingPathComponent(".var/app/io.github.elly_code.jorts/data/io.github.elly_code.jorts/saved_state.json"),
            home.appendingPathComponent(".var/app/io.github.elly_code.jorts/data/io.github.elly_code.jorts/saved_data.json"),
            home.appendingPathComponent(".var/app/io.github.ellie_commons.jorts/data/io.github.ellie_commons.jorts/saved_state.json"),
            home.appendingPathComponent(".var/app/io.github.ellie_commons.jorts/data/io.github.ellie_commons.jorts/saved_data.json"),
            home.appendingPathComponent(".local/share/io.github.elly_code.jorts/saved_state.json"),
            home.appendingPathComponent(".local/share/io.github.ellie_commons.jorts/saved_state.json")
        ]
    }
}

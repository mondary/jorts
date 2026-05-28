import Foundation

final class NoteStorage {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    let storageURL: URL
    private let notesDirectory: URL
    private let trashDirectory: URL
    private let forcedJSONSeedURL = URL(fileURLWithPath: "/Users/clm/Documents/JortsMacOS/saved_state.json")

    init(storageDirectoryOverride: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()

        let documentsDirectory = try? fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let appFolderName = "JortsMacOS"
        let defaultStorageDirectory = (documentsDirectory ?? fileManager.homeDirectoryForCurrentUser)
            .appendingPathComponent(appFolderName, isDirectory: true)
        let normalizedOverride = storageDirectoryOverride.map { override in
            override.lastPathComponent == appFolderName
            ? override
            : override.appendingPathComponent(appFolderName, isDirectory: true)
        }
        let storageDirectory = normalizedOverride ?? defaultStorageDirectory
        storageURL = storageDirectory.appendingPathComponent("saved_state.json")
        notesDirectory = storageDirectory.appendingPathComponent("Notes", isDirectory: true)
        trashDirectory = storageDirectory.appendingPathComponent("Trash", isDirectory: true)
        prepareStorageDirectory(storageDirectory)
        prepareStorageDirectory(notesDirectory)
        prepareStorageDirectory(trashDirectory)
        importLegacySaveIfNeeded(to: storageURL)

        // One-time migration: if we don't have any .md notes yet but we do have JSON, convert JSON -> .md
        migrateJSONToMarkdownIfNeeded()
        migrateForcedSeedJSONIfNeeded()

        // Cleanup: if duplicate md files exist for the same UUID, consolidate into one file (versions merged)
        consolidateDuplicateMarkdownNotesIfNeeded()
        externalizeInlineVersionsIfNeeded()
        canonicalizeMarkdownStateIfNeeded()
    }

    func loadState() -> SavedState {
        // Preferred format: one Markdown file per note, one sibling JSON file for versions.
        if let state = loadFromMarkdownFiles() {
            return state
        }

        // Fallback: legacy JSON (only if markdown storage is empty).
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
            NSLog("JortsMacOSMac: failed to load notes from \(storageURL.path): \(error)")
            return SavedState()
        }
    }

    func saveState(_ state: SavedState) {
        // Write the new format first (per-note Markdown + sibling versions JSON).
        do {
            try saveToMarkdownFiles(state)
        } catch {
            NSLog("JortsMacOSMac: failed to save notes as Markdown files: \(error)")
        }
    }

    private func migrateJSONToMarkdownIfNeeded() {
        do {
            let noteFiles = (try? fileManager.contentsOfDirectory(at: notesDirectory, includingPropertiesForKeys: nil)) ?? []
            let trashFiles = (try? fileManager.contentsOfDirectory(at: trashDirectory, includingPropertiesForKeys: nil)) ?? []
            let hasMarkdown = noteFiles.contains(where: { $0.pathExtension.lowercased() == "md" }) ||
                trashFiles.contains(where: { $0.pathExtension.lowercased() == "md" })
            guard !hasMarkdown else { return }
            guard fileManager.fileExists(atPath: storageURL.path) else { return }

            let data = try Data(contentsOf: storageURL)
            let state: SavedState
            if let decoded = try? decoder.decode(SavedState.self, from: data) {
                state = decoded
            } else if let notes = try? decoder.decode([NoteData].self, from: data) {
                state = SavedState(notes: notes, trash: [])
            } else {
                return
            }

            try saveToMarkdownFiles(state)

            // Rename JSON so it doesn't re-contaminate state.
            let backupURL = storageURL.deletingLastPathComponent().appendingPathComponent("saved_state.json.bak")
            try? fileManager.removeItem(at: backupURL)
            try fileManager.moveItem(at: storageURL, to: backupURL)
        } catch {
            NSLog("JortsMacOSMac: JSON->MD migration failed: \(error)")
        }
    }

    private func migrateForcedSeedJSONIfNeeded() {
        // If the user deleted Notes/Trash, regenerate canonical .md from the seed JSON.
        guard fileManager.fileExists(atPath: forcedJSONSeedURL.path) else { return }

        let noteFiles = (try? fileManager.contentsOfDirectory(at: notesDirectory, includingPropertiesForKeys: nil)) ?? []
        let trashFiles = (try? fileManager.contentsOfDirectory(at: trashDirectory, includingPropertiesForKeys: nil)) ?? []
        let hasMarkdown = noteFiles.contains(where: { $0.pathExtension.lowercased() == "md" }) ||
            trashFiles.contains(where: { $0.pathExtension.lowercased() == "md" })
        guard !hasMarkdown else { return }

        do {
            let data = try Data(contentsOf: forcedJSONSeedURL)
            let state = try decoder.decode(SavedState.self, from: data)
            try saveToMarkdownFiles(state)
        } catch {
            NSLog("JortsMacOSMac: forced seed JSON -> MD migration failed: \(error)")
        }
    }

    private func consolidateDuplicateMarkdownNotesIfNeeded() {
        do {
            try consolidateDuplicates(in: notesDirectory, duplicatesSubdirName: "Duplicates")
            try consolidateDuplicates(in: trashDirectory, duplicatesSubdirName: "Duplicates")
        } catch {
            NSLog("JortsMacOSMac: duplicate consolidation failed: \(error)")
        }
    }

    private func consolidateDuplicates(in directory: URL, duplicatesSubdirName: String) throws {
        let files = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let mdFiles = files.filter { $0.pathExtension.lowercased() == "md" }
        guard mdFiles.count > 1 else { return }

        var byID: [UUID: [(url: URL, note: NoteData, deletedAt: Date?)]] = [:]

        for url in mdFiles {
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let (fm, body) = parseFrontMatter(raw)
            guard let idString = fm["id"], let id = UUID(uuidString: idString) else { continue }

            let (cleanBody, versions) = extractVersions(from: body)
            var note = decodeNote(frontMatter: fm, body: cleanBody)
            note.id = id
            note.versions = mergedVersions(readVersions(forMarkdownURL: url), versions)
            let deletedAt = decodeDate(fm["deletedAt"])
            byID[id, default: []].append((url: url, note: note, deletedAt: deletedAt))
        }

        let duplicatesDir = directory.appendingPathComponent(duplicatesSubdirName, isDirectory: true)
        prepareStorageDirectory(duplicatesDir)

        for (_, entries) in byID where entries.count > 1 {
            // Merge: pick the most recently modified file as base, merge versions/content.
            let sorted = entries.sorted { lhs, rhs in
                let ldate = (try? lhs.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rdate = (try? rhs.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return ldate > rdate
            }
            var merged = sorted.first!.note

            // Merge versions (union by version.id, keep latest by date if duplicates)
            var versionsByID: [UUID: NoteVersion] = [:]
            for entry in sorted {
                for v in entry.note.versions {
                    if let existing = versionsByID[v.id] {
                        versionsByID[v.id] = (v.date > existing.date) ? v : existing
                    } else {
                        versionsByID[v.id] = v
                    }
                }
            }
            merged.versions = versionsByID.values.sorted { $0.date < $1.date }

            // If some duplicates have longer content/title, prefer that.
            if let best = sorted.max(by: { $0.note.content.count < $1.note.content.count }) {
                merged.content = best.note.content
            }
            if let bestTitle = sorted.max(by: { $0.note.title.count < $1.note.title.count }) {
                merged.title = bestTitle.note.title
            }

            // For trash notes, keep the most recent deletedAt we can find.
            let deletedAt = sorted.compactMap(\.deletedAt).max()

            // Write canonical human-readable file.
            let canonicalURL = markdownURL(for: merged, in: directory, usedNames: [])
            let text: String
            if let deletedAt {
                text = serialize(note: merged, extraFrontMatter: ["deletedAt": encodeDate(deletedAt)])
            } else {
                text = serialize(note: merged)
            }
            try text.write(to: canonicalURL, atomically: true, encoding: .utf8)
            try saveVersions(merged.versions, forMarkdownURL: canonicalURL)

            // Move all other files to Duplicates/
            for entry in entries {
                if entry.url.lastPathComponent == canonicalURL.lastPathComponent { continue }
                try? fileManager.removeItem(at: versionsURL(forMarkdownURL: entry.url))
                let target = duplicatesDir.appendingPathComponent(entry.url.lastPathComponent)
                try? fileManager.removeItem(at: target)
                try? fileManager.moveItem(at: entry.url, to: target)
            }
        }
    }

    private func externalizeInlineVersionsIfNeeded() {
        do {
            try externalizeInlineVersions(in: notesDirectory)
            try externalizeInlineVersions(in: trashDirectory)
        } catch {
            NSLog("JortsMacOSMac: inline versions migration failed: \(error)")
        }
    }

    private func externalizeInlineVersions(in directory: URL) throws {
        let files = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension.lowercased() == "md" {
            let raw = try String(contentsOf: url, encoding: .utf8)
            let (frontMatter, body) = parseFrontMatter(raw)
            let (cleanBody, inlineVersions) = extractVersions(from: body)
            guard !inlineVersions.isEmpty else { continue }

            var note = decodeNote(frontMatter: frontMatter, body: cleanBody)
            note.versions = mergedVersions(readVersions(forMarkdownURL: url), inlineVersions)
            try saveVersions(note.versions, forMarkdownURL: url)

            var extra: [String: String] = [:]
            if let deletedAt = frontMatter["deletedAt"] {
                extra["deletedAt"] = deletedAt
            }
            let text = serialize(note: note, extraFrontMatter: extra)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func canonicalizeMarkdownStateIfNeeded() {
        guard let state = loadFromMarkdownFiles() else { return }
        do {
            try saveToMarkdownFiles(state)
        } catch {
            NSLog("JortsMacOSMac: markdown canonicalization failed: \(error)")
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

            // Deduplicate by UUID in case multiple files exist for the same note (e.g. title slug changed).
            var notesByID: [UUID: NoteData] = [:]
            for url in noteFiles {
                if let note = try? readNoteMarkdown(from: url) {
                    notesByID[note.id] = merge(existing: notesByID[note.id], incoming: note)
                }
            }
            var trashByID: [UUID: TrashedNote] = [:]
            for url in trashFiles {
                if let item = try? readTrashedMarkdown(from: url) {
                    trashByID[item.id] = merge(existing: trashByID[item.id], incoming: item)
                }
            }
            let trash = deduplicateTrash(Array(trashByID.values))
            let trashSignatures = Set(trash.map { readableSignature(title: $0.note.title, content: $0.note.content) })
            let notes = deduplicateNotes(Array(notesByID.values))
                .filter { !trashSignatures.contains(readableSignature(title: $0.title, content: $0.content)) }

            return SavedState(notes: notes, trash: trash.sorted { $0.deletedAt > $1.deletedAt })
        } catch {
            NSLog("JortsMacOSMac: failed to load Markdown notes: \(error)")
            return nil
        }
    }

    private func saveToMarkdownFiles(_ state: SavedState) throws {
        var usedNoteNames = Set<String>()
        var usedTrashNames = Set<String>()
        let noteIDs = Set(state.notes.map(\.id))
        let trashIDs = Set(state.trash.map(\.id))

        // Notes
        for note in state.notes {
            // Remove any previous files for this UUID (old slugs).
            try removeFiles(matchingUUID: note.id, in: notesDirectory)
            let url = markdownURL(for: note, in: notesDirectory, usedNames: usedNoteNames)
            usedNoteNames.insert(url.lastPathComponent)
            let text = serialize(note: note)
            try text.write(to: url, atomically: true, encoding: .utf8)
            try saveVersions(note.versions, forMarkdownURL: url)
        }
        try pruneMarkdownFiles(excludingIDs: noteIDs, in: notesDirectory)

        // Trash
        for trashed in state.trash {
            try removeFiles(matchingUUID: trashed.id, in: trashDirectory)
            let url = markdownURL(for: trashed.note, in: trashDirectory, usedNames: usedTrashNames)
            usedTrashNames.insert(url.lastPathComponent)
            let text = serialize(trashed: trashed)
            try text.write(to: url, atomically: true, encoding: .utf8)
            try saveVersions(trashed.note.versions, forMarkdownURL: url)
        }
        try pruneMarkdownFiles(excludingIDs: trashIDs, in: trashDirectory)
    }

    private func removeFiles(matchingUUID id: UUID, in directory: URL) throws {
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let markdownNeedle = "--\(id.uuidString).md"
        let versionsNeedle = "--\(id.uuidString).versions.json"
        for url in files {
            if url.lastPathComponent.hasSuffix(markdownNeedle) || url.lastPathComponent.hasSuffix(versionsNeedle) {
                try? fileManager.removeItem(at: url)
                continue
            }

            guard url.pathExtension.lowercased() == "md",
                  let raw = try? String(contentsOf: url, encoding: .utf8) else {
                continue
            }
            let (frontMatter, _) = parseFrontMatter(raw)
            guard frontMatter["id"] == id.uuidString else { continue }
            try? fileManager.removeItem(at: versionsURL(forMarkdownURL: url))
            try? fileManager.removeItem(at: url)
        }
    }

    private func markdownURL(for note: NoteData, in directory: URL, usedNames: Set<String>) -> URL {
        let baseName = slugify(note.title)
        var candidate = "\(baseName).md"
        var index = 2
        while usedNames.contains(candidate) {
            candidate = "\(baseName)-\(index).md"
            index += 1
        }
        return directory.appendingPathComponent(candidate)
    }

    private func versionsURL(forMarkdownURL markdownURL: URL) -> URL {
        let baseName = markdownURL.deletingPathExtension().lastPathComponent
        return markdownURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(baseName).json")
    }

    private func slugify(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Untitled" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let dashed = trimmed
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: allowed.inverted)
            .joined()
        return dashed.isEmpty ? "Untitled" : String(dashed.prefix(60))
    }

    private func readNoteMarkdown(from url: URL) throws -> NoteData {
        let content = try String(contentsOf: url, encoding: .utf8)
        let (frontMatter, body) = parseFrontMatter(content)
        let (cleanBody, versions) = extractVersions(from: body)
        var note = decodeNote(frontMatter: frontMatter, body: cleanBody)
        note.versions = mergedVersions(readVersions(forMarkdownURL: url), versions)
        return note
    }

    private func readTrashedMarkdown(from url: URL) throws -> TrashedNote {
        let content = try String(contentsOf: url, encoding: .utf8)
        let (frontMatter, body) = parseFrontMatter(content)
        let (cleanBody, versions) = extractVersions(from: body)
        var note = decodeNote(frontMatter: frontMatter, body: cleanBody)
        note.versions = mergedVersions(readVersions(forMarkdownURL: url), versions)
        let deletedAt = decodeDate(frontMatter["deletedAt"]) ?? Date()
        return TrashedNote(note: note, deletedAt: deletedAt)
    }

    private func readVersions(forMarkdownURL markdownURL: URL) -> [NoteVersion] {
        let url = versionsURL(forMarkdownURL: markdownURL)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let versions = try? decoder.decode([NoteVersion].self, from: data) else {
            return []
        }
        return versions
    }

    private func saveVersions(_ versions: [NoteVersion], forMarkdownURL markdownURL: URL) throws {
        let url = versionsURL(forMarkdownURL: markdownURL)
        guard !versions.isEmpty else {
            try? fileManager.removeItem(at: url)
            return
        }
        let data = try encoder.encode(versions)
        try data.write(to: url, options: .atomic)
    }

    private func mergedVersions(_ lhs: [NoteVersion], _ rhs: [NoteVersion]) -> [NoteVersion] {
        var byID: [UUID: NoteVersion] = [:]
        for version in lhs + rhs {
            if let existing = byID[version.id] {
                byID[version.id] = version.date > existing.date ? version : existing
            } else {
                byID[version.id] = version
            }
        }
        return byID.values.sorted { $0.date < $1.date }
    }

    private func merge(existing: NoteData?, incoming: NoteData) -> NoteData {
        guard var existing else { return incoming }
        existing.versions = mergedVersions(existing.versions, incoming.versions)
        if incoming.content.count >= existing.content.count {
            existing.content = incoming.content
        }
        if incoming.title.count >= existing.title.count {
            existing.title = incoming.title
        }
        existing.theme = incoming.theme
        existing.monospace = incoming.monospace
        existing.fontFamily = incoming.fontFamily
        existing.zoom = incoming.zoom
        existing.width = incoming.width
        existing.height = incoming.height
        existing.x = incoming.x ?? existing.x
        existing.y = incoming.y ?? existing.y
        existing.macFrameVersion = incoming.macFrameVersion
        return existing
    }

    private func merge(existing: TrashedNote?, incoming: TrashedNote) -> TrashedNote {
        guard var existing else { return incoming }
        existing.note = merge(existing: existing.note, incoming: incoming.note)
        if incoming.deletedAt > existing.deletedAt {
            existing.deletedAt = incoming.deletedAt
        }
        return existing
    }

    private func deduplicateNotes(_ notes: [NoteData]) -> [NoteData] {
        var bySignature: [String: NoteData] = [:]
        for note in notes {
            let key = readableSignature(title: note.title, content: note.content)
            bySignature[key] = merge(existing: bySignature[key], incoming: note)
        }
        return Array(bySignature.values)
    }

    private func deduplicateTrash(_ trash: [TrashedNote]) -> [TrashedNote] {
        var bySignature: [String: TrashedNote] = [:]
        for item in trash {
            let key = readableSignature(title: item.note.title, content: item.note.content)
            bySignature[key] = merge(existing: bySignature[key], incoming: item)
        }
        return Array(bySignature.values)
    }

    private func readableSignature(title: String, content: String) -> String {
        "\(title.trimmingCharacters(in: .whitespacesAndNewlines))\n\(content.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    private func pruneMarkdownFiles(excludingIDs ids: Set<UUID>, in directory: URL) throws {
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in files where url.pathExtension.lowercased() == "md" {
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let (frontMatter, _) = parseFrontMatter(raw)
            guard let rawID = frontMatter["id"],
                  let id = UUID(uuidString: rawID),
                  !ids.contains(id) else {
                continue
            }
            try? fileManager.removeItem(at: versionsURL(forMarkdownURL: url))
            try? fileManager.removeItem(at: url)
        }
    }

    private func serialize(note: NoteData, extraFrontMatter: [String: String] = [:]) -> String {
        var metadata: [String: String] = [
            "id": note.id.uuidString,
            "title": escape(note.title),
            "theme": String(note.theme.rawValue),
            "monospace": String(note.monospace),
            "fontFamily": escape(note.fontFamily.rawValue),
            "zoom": String(note.zoom),
            "width": String(note.width),
            "height": String(note.height),
            "macFrameVersion": String(note.macFrameVersion)
        ]
        if let x = note.x { metadata["x"] = String(x) }
        if let y = note.y { metadata["y"] = String(y) }
        for (k, v) in extraFrontMatter {
            metadata[k] = escape(v)
        }

        var output = note.content
        if !output.hasSuffix("\n") {
            output.append("\n")
        }
        output.append("\n")
        output.append(serializeTrailingMetadata(metadata))
        output.append("\n")
        return output
    }

    private func serialize(trashed: TrashedNote) -> String {
        serialize(note: trashed.note, extraFrontMatter: ["deletedAt": encodeDate(trashed.deletedAt)])
    }

    private func parseFrontMatter(_ input: String) -> ([String: String], String) {
        var frontMatter: [String: String] = [:]
        var body = input

        if input.hasPrefix("---\n"),
           let endRange = input.range(of: "\n---\n", options: [], range: input.index(input.startIndex, offsetBy: 4)..<input.endIndex) {
            let fmBlock = String(input[input.index(input.startIndex, offsetBy: 4)..<endRange.lowerBound])
            body = String(input[endRange.upperBound...])
            frontMatter = parseKeyValueBlock(fmBlock)
        }

        let (trailingMetadata, cleanBody) = parseTrailingMetadata(from: body)
        var merged = trailingMetadata
        for (k, v) in frontMatter {
            merged[k] = v
        }

        return (merged, cleanBody)
    }

    private func parseTrailingMetadata(from body: String) -> ([String: String], String) {
        let startMarker = "\n<!-- JORTS_META\n"
        guard let markerRange = body.range(of: startMarker, options: .backwards) else {
            return ([:], body)
        }

        let metadataStart = markerRange.upperBound
        guard let endRange = body.range(of: "\n-->", range: metadataStart..<body.endIndex) else {
            return ([:], body)
        }

        let block = String(body[metadataStart..<endRange.lowerBound])
        let metadata = parseKeyValueBlock(block)

        var cleanBody = String(body[..<markerRange.lowerBound])
        cleanBody = cleanBody.trimmingCharacters(in: .newlines) + "\n"
        return (metadata, cleanBody)
    }

    private func parseKeyValueBlock(_ block: String) -> [String: String] {
        var dict: [String: String] = [:]
        for line in block.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            dict[key] = unescape(value)
        }
        return dict
    }

    private func serializeTrailingMetadata(_ metadata: [String: String]) -> String {
        let preferredOrder = [
            "id", "title", "theme", "monospace", "fontFamily", "zoom",
            "width", "height", "x", "y", "macFrameVersion", "deletedAt"
        ]

        var lines: [String] = ["<!-- JORTS_META"]
        var keys = preferredOrder.filter { metadata[$0] != nil }
        keys.append(contentsOf: metadata.keys.filter { !preferredOrder.contains($0) }.sorted())

        for key in keys {
            guard let value = metadata[key] else { continue }
            lines.append("\(key): \(value)")
        }
        lines.append("-->")
        return lines.joined(separator: "\n")
    }

    private func decodeNote(frontMatter: [String: String], body: String) -> NoteData {
        var normalizedBody = body
        if normalizedBody.hasPrefix("\r\n") {
            normalizedBody.removeFirst(2)
        } else if normalizedBody.hasPrefix("\n") {
            normalizedBody.removeFirst(1)
        }

        var note = NoteData(
            title: frontMatter["title"] ?? "",
            theme: NoteTheme(rawValue: Int(frontMatter["theme"] ?? "") ?? NoteTheme.blueberry.rawValue) ?? .blueberry,
            content: normalizedBody,
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

    private func extractVersions(from body: String) -> (String, [NoteVersion]) {
        guard let markerRange = body.range(of: "\n<!-- JORTS_VERSIONS\n") else {
            return (body, [])
        }

        let head = String(body[..<markerRange.lowerBound])
        let rest = String(body[markerRange.upperBound...])
        guard let endRange = rest.range(of: "\n-->\n") ?? rest.range(of: "\n-->") else {
            return (body, [])
        }

        let json = String(rest[..<endRange.lowerBound])
        let tail = String(rest[endRange.upperBound...])
        let cleaned = (head + tail).trimmingCharacters(in: .newlines) + "\n"

        guard let data = json.data(using: .utf8),
              let versions = try? JSONDecoder().decode([NoteVersion].self, from: data) else {
            return (cleaned, [])
        }

        return (cleaned, versions)
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
            NSLog("JortsMacOSMac: failed to create storage directory \(directory.path): \(error)")
        }
    }

    private func importLegacySaveIfNeeded(to destinationURL: URL) {
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            return
        }

        for candidate in legacySaveCandidates() where fileManager.fileExists(atPath: candidate.path) {
            do {
                try fileManager.copyItem(at: candidate, to: destinationURL)
                NSLog("JortsMacOSMac: imported legacy JortsMacOS save from \(candidate.path)")
                return
            } catch {
                NSLog("JortsMacOSMac: failed to import legacy save \(candidate.path): \(error)")
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

private extension StringProtocol {
    var nilIfEmpty: String? { isEmpty ? nil : String(self) }
}

import Foundation

final class NoteStorage {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    let storageURL: URL

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
            .appendingPathComponent("io.github.elly_code.jorts.macos", isDirectory: true)
        storageURL = storageDirectory.appendingPathComponent("saved_state.json")
        prepareStorageDirectory(storageDirectory)
        importLegacySaveIfNeeded(to: storageURL)
    }

    func loadState() -> SavedState {
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return SavedState()
        }

        do {
            let data = try Data(contentsOf: storageURL)
            if let state = try? decoder.decode(SavedState.self, from: data) {
                return state
            }
            // Backward compatibility: legacy format was a flat [NoteData]
            let notes = try decoder.decode([NoteData].self, from: data)
            return SavedState(notes: notes, trash: [])
        } catch {
            NSLog("JortsMac: failed to load notes from \(storageURL.path): \(error)")
            return SavedState()
        }
    }

    func saveState(_ state: SavedState) {
        do {
            let data = try encoder.encode(state)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            NSLog("JortsMac: failed to save notes to \(storageURL.path): \(error)")
        }
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

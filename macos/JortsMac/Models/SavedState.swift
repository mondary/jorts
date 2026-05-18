import Foundation

struct SavedState: Codable {
    var notes: [NoteData]
    var trash: [TrashedNote]

    init(notes: [NoteData] = [], trash: [TrashedNote] = []) {
        self.notes = notes
        self.trash = trash
    }
}

struct TrashedNote: Codable, Identifiable {
    var id: UUID
    var deletedAt: Date
    var note: NoteData

    init(note: NoteData, deletedAt: Date = Date()) {
        self.id = note.id
        self.deletedAt = deletedAt
        self.note = note
    }
}


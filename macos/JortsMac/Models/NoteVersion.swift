import Foundation

struct NoteVersion: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var title: String
    var content: String
    var theme: NoteTheme
    var monospace: Bool
    var fontFamily: FontFamily
    var zoom: Int
}


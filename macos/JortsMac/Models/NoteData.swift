import Foundation

struct NoteData: Codable, Identifiable {
    static let defaultWidth = 290
    static let defaultHeight = 320
    static let defaultZoom = 100
    static let minimumZoom = 20
    static let maximumZoom = 300

    var id = UUID()
    var title: String
    var theme: NoteTheme
    var content: String
    var monospace: Bool
    var zoom: Int
    var width: Int
    var height: Int

    enum CodingKeys: String, CodingKey {
        case title
        case color
        case content
        case monospace
        case zoom
        case width
        case height
    }

    init(
        title: String = RandomContent.title(),
        theme: NoteTheme = .blueberry,
        content: String = "",
        monospace: Bool = false,
        zoom: Int = NoteData.defaultZoom,
        width: Int = NoteData.defaultWidth,
        height: Int = NoteData.defaultHeight
    ) {
        self.title = title
        self.theme = theme
        self.content = content
        self.monospace = monospace
        self.zoom = zoom.clamped(to: NoteData.minimumZoom...NoteData.maximumZoom)
        self.width = max(220, width)
        self.height = max(220, height)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? RandomContent.title()
        let colorValue = try container.decodeIfPresent(Int.self, forKey: .color) ?? NoteTheme.blueberry.rawValue
        theme = NoteTheme(rawValue: colorValue) ?? .blueberry
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        monospace = try container.decodeIfPresent(Bool.self, forKey: .monospace) ?? false
        let decodedZoom = try container.decodeIfPresent(Int.self, forKey: .zoom) ?? NoteData.defaultZoom
        zoom = decodedZoom.clamped(to: NoteData.minimumZoom...NoteData.maximumZoom)
        width = max(220, try container.decodeIfPresent(Int.self, forKey: .width) ?? NoteData.defaultWidth)
        height = max(220, try container.decodeIfPresent(Int.self, forKey: .height) ?? NoteData.defaultHeight)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(theme.rawValue, forKey: .color)
        try container.encode(content, forKey: .content)
        try container.encode(monospace, forKey: .monospace)
        try container.encode(zoom, forKey: .zoom)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}

import Foundation

struct NoteData: Codable, Identifiable {
    static let defaultWidth = 580
    static let defaultHeight = 640
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
    var x: Double?
    var y: Double?

    enum CodingKeys: String, CodingKey {
        case title
        case color
        case content
        case monospace
        case zoom
        case width
        case height
        case x
        case y
    }

    init(
        title: String = RandomContent.title(),
        theme: NoteTheme = .blueberry,
        content: String = "",
        monospace: Bool = false,
        zoom: Int = NoteData.defaultZoom,
        width: Int = NoteData.defaultWidth,
        height: Int = NoteData.defaultHeight,
        x: Double? = nil,
        y: Double? = nil
    ) {
        self.title = title
        self.theme = theme
        self.content = content
        self.monospace = monospace
        self.zoom = zoom.clamped(to: NoteData.minimumZoom...NoteData.maximumZoom)
        self.width = max(240, width)
        self.height = max(240, height)
        self.x = x
        self.y = y
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
        width = max(240, try container.decodeIfPresent(Int.self, forKey: .width) ?? NoteData.defaultWidth)
        height = max(240, try container.decodeIfPresent(Int.self, forKey: .height) ?? NoteData.defaultHeight)
        x = try container.decodeIfPresent(Double.self, forKey: .x)
        y = try container.decodeIfPresent(Double.self, forKey: .y)
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
        if let x = x { try container.encode(x, forKey: .x) }
        if let y = y { try container.encode(y, forKey: .y) }
    }
}

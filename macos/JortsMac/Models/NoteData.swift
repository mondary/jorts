import Foundation

struct NoteData: Codable, Identifiable {
    static let defaultWidth = 580
    static let defaultHeight = 640
    static let defaultZoom = 100
    static let minimumZoom = 20
    static let maximumZoom = 300
    static let currentMacFrameVersion = 1

    var id = UUID()
    var title: String
    var theme: NoteTheme
    var content: String
    var monospace: Bool
    var fontFamily: FontFamily
    var zoom: Int
    var width: Int
    var height: Int
    var x: Double?
    var y: Double?
    var macFrameVersion: Int
    var versions: [NoteVersion]

    enum CodingKeys: String, CodingKey {
        case title
        case color
        case content
        case monospace
        case fontFamily
        case zoom
        case width
        case height
        case x
        case y
        case macFrameVersion
        case versions
    }

    init(
        title: String = RandomContent.title(),
        theme: NoteTheme = .blueberry,
        content: String = "",
        monospace: Bool = false,
        fontFamily: FontFamily = .system,
        zoom: Int = NoteData.defaultZoom,
        width: Int = NoteData.defaultWidth,
        height: Int = NoteData.defaultHeight,
        x: Double? = nil,
        y: Double? = nil,
        macFrameVersion: Int = NoteData.currentMacFrameVersion,
        versions: [NoteVersion] = []
    ) {
        self.title = title
        self.theme = theme
        self.content = content
        self.monospace = monospace
        self.fontFamily = fontFamily
        self.zoom = zoom.clamped(to: NoteData.minimumZoom...NoteData.maximumZoom)
        self.width = max(240, width)
        self.height = max(240, height)
        self.x = x
        self.y = y
        self.macFrameVersion = macFrameVersion
        self.versions = versions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? RandomContent.title()
        let colorValue = try container.decodeIfPresent(Int.self, forKey: .color) ?? NoteTheme.blueberry.rawValue
        theme = NoteTheme(rawValue: colorValue) ?? .blueberry
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        monospace = try container.decodeIfPresent(Bool.self, forKey: .monospace) ?? false
        fontFamily = try container.decodeIfPresent(FontFamily.self, forKey: .fontFamily) ?? .system
        let decodedZoom = try container.decodeIfPresent(Int.self, forKey: .zoom) ?? NoteData.defaultZoom
        zoom = decodedZoom.clamped(to: NoteData.minimumZoom...NoteData.maximumZoom)
        let decodedWidth = try container.decodeIfPresent(Int.self, forKey: .width) ?? NoteData.defaultWidth
        let decodedHeight = try container.decodeIfPresent(Int.self, forKey: .height) ?? NoteData.defaultHeight
        macFrameVersion = try container.decodeIfPresent(Int.self, forKey: .macFrameVersion) ?? 0
        versions = try container.decodeIfPresent([NoteVersion].self, forKey: .versions) ?? []

        if macFrameVersion == 0 && decodedWidth <= 260 && decodedHeight <= 300 {
            width = NoteData.defaultWidth
            height = NoteData.defaultHeight
        } else {
            width = max(240, decodedWidth)
            height = max(240, decodedHeight)
        }

        x = try container.decodeIfPresent(Double.self, forKey: .x)
        y = try container.decodeIfPresent(Double.self, forKey: .y)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(theme.rawValue, forKey: .color)
        try container.encode(content, forKey: .content)
        try container.encode(monospace, forKey: .monospace)
        try container.encode(fontFamily, forKey: .fontFamily)
        try container.encode(zoom, forKey: .zoom)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        if let x = x { try container.encode(x, forKey: .x) }
        if let y = y { try container.encode(y, forKey: .y) }
        try container.encode(NoteData.currentMacFrameVersion, forKey: .macFrameVersion)
        if !versions.isEmpty {
            try container.encode(versions, forKey: .versions)
        }
    }
}

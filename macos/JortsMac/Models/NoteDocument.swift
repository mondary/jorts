import CoreGraphics
import Foundation

final class NoteDocument: ObservableObject, Identifiable {
    let id: UUID
    var onChange: (() -> Void)?

    @Published var title: String {
        didSet {
            guard title != oldValue else { return }
            markChanged()
        }
    }

    @Published var content: String {
        didSet {
            guard content != oldValue else { return }
            markChanged()
        }
    }

    @Published var theme: NoteTheme {
        didSet {
            guard theme != oldValue else { return }
            markChanged()
        }
    }

    @Published var monospace: Bool {
        didSet {
            guard monospace != oldValue else { return }
            markChanged()
        }
    }

    @Published var zoom: Int {
        didSet {
            let clampedZoom = zoom.clamped(to: NoteData.minimumZoom...NoteData.maximumZoom)
            if zoom != clampedZoom {
                zoom = clampedZoom
                return
            }

            guard zoom != oldValue else { return }
            markChanged()
        }
    }

    @Published var size: CGSize {
        didSet {
            guard abs(size.width - oldValue.width) > 0.5 || abs(size.height - oldValue.height) > 0.5 else { return }
            markChanged()
        }
    }

    @Published var isFocused = true
    @Published var listToggleRequestToken = 0

    init(data: NoteData) {
        id = data.id
        title = data.title
        content = data.content
        theme = data.theme
        monospace = data.monospace
        zoom = data.zoom
        size = CGSize(width: data.width, height: data.height)
    }

    var windowTitle: String {
        "\(title.isEmpty ? "Untitled" : title) - Jorts"
    }

    var textScale: CGFloat {
        CGFloat(zoom) / 100.0
    }

    var bodyFontSize: CGFloat {
        (15.0 * textScale).clamped(to: 11.0...42.0)
    }

    var titleFontSize: CGFloat {
        (16.0 * textScale).clamped(to: 12.0...44.0)
    }

    func package() -> NoteData {
        NoteData(
            title: title,
            theme: theme,
            content: content,
            monospace: monospace,
            zoom: zoom,
            width: Int(size.width.rounded()),
            height: Int(size.height.rounded())
        )
    }

    func zoomIn() {
        zoom += 20
    }

    func zoomOut() {
        zoom -= 20
    }

    func resetZoom() {
        zoom = NoteData.defaultZoom
    }

    func toggleList() {
        listToggleRequestToken += 1
    }

    private func markChanged() {
        onChange?()
    }
}

import AppKit
import Combine

final class ClipboardManager: ObservableObject {
    struct Item: Identifiable, Equatable {
        enum Kind: String, Codable {
            case text
            case url
            case image
            case fileURLs
        }

        let id: UUID
        let createdAt: Date
        let sourceBundleID: String?
        let sourceAppName: String?
        let kind: Kind
        let previewText: String
        let payload: Payload

        enum Payload: Equatable {
            case text(String)
            case url(URL)
            case imageData(Data)
            case fileURLs([URL])
        }
    }

    @Published private(set) var items: [Item] = []

    var isPaused: Bool = false

    private let pasteboard: NSPasteboard
    private var lastChangeCount: Int
    private var timer: Timer?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        stop()
        // Polling is reliable across apps without requiring accessibility permissions.
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func clear() {
        items.removeAll()
    }

    func copyToPasteboard(_ item: Item) {
        switch item.payload {
        case .text(let text):
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        case .url(let url):
            pasteboard.clearContents()
            pasteboard.writeObjects([url as NSURL])
        case .imageData(let data):
            guard let image = NSImage(data: data) else { return }
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
        case .fileURLs(let urls):
            pasteboard.clearContents()
            pasteboard.writeObjects(urls as [NSURL])
        }
    }

    private func poll() {
        guard !isPaused else { return }
        let cc = pasteboard.changeCount
        guard cc != lastChangeCount else { return }
        lastChangeCount = cc
        captureCurrentPasteboard()
    }

    private func captureCurrentPasteboard() {
        let (bundleID, appName) = frontmostAppIdentity()

        // Prefer file URLs, then images, then string.
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty
        {
            let preview = urls.first?.lastPathComponent ?? "Files"
            append(Item(
                id: UUID(),
                createdAt: Date(),
                sourceBundleID: bundleID,
                sourceAppName: appName,
                kind: .fileURLs,
                previewText: preview,
                payload: .fileURLs(urls)
            ))
            return
        }

        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let first = images.first,
           let tiff = first.tiffRepresentation
        {
            append(Item(
                id: UUID(),
                createdAt: Date(),
                sourceBundleID: bundleID,
                sourceAppName: appName,
                kind: .image,
                previewText: "Image",
                payload: .imageData(tiff)
            ))
            return
        }

        if let s = pasteboard.string(forType: .string), !s.isEmpty {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
                append(Item(
                    id: UUID(),
                    createdAt: Date(),
                    sourceBundleID: bundleID,
                    sourceAppName: appName,
                    kind: .url,
                    previewText: trimmed,
                    payload: .url(url)
                ))
            } else {
                append(Item(
                    id: UUID(),
                    createdAt: Date(),
                    sourceBundleID: bundleID,
                    sourceAppName: appName,
                    kind: .text,
                    previewText: String(trimmed.prefix(240)),
                    payload: .text(s)
                ))
            }
        }
    }

    private func append(_ item: Item) {
        // De-dupe simple: if last item has same preview/kind/source, ignore.
        if let last = items.first,
           last.kind == item.kind,
           last.previewText == item.previewText,
           last.sourceBundleID == item.sourceBundleID
        {
            return
        }

        items.insert(item, at: 0)
        if items.count > 500 {
            items.removeLast(items.count - 500)
        }
    }

    private func frontmostAppIdentity() -> (bundleID: String?, name: String?) {
        let app = NSWorkspace.shared.frontmostApplication
        return (app?.bundleIdentifier, app?.localizedName)
    }
}


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
    private let persistence: ClipboardPersistence
    private var saveWorkItem: DispatchWorkItem?

    init(pasteboard: NSPasteboard = .general, persistence: ClipboardPersistence = .shared) {
        self.pasteboard = pasteboard
        self.persistence = persistence
        self.lastChangeCount = pasteboard.changeCount
        self.items = persistence.load()
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
        persistence.clear()
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
        scheduleSave()
    }

    private func frontmostAppIdentity() -> (bundleID: String?, name: String?) {
        let app = NSWorkspace.shared.frontmostApplication
        return (app?.bundleIdentifier, app?.localizedName)
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.persistence.save(self.items)
        }
        saveWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.35, execute: work)
    }
}

// MARK: - Persistence

final class ClipboardPersistence {
    static let shared = ClipboardPersistence(baseDirectory: nil)

    // If nil, we fall back to the default NoteStorage location (Documents/JortsMacOS).
    private let baseDirectoryOverride: URL?

    init(baseDirectory: URL?) {
        self.baseDirectoryOverride = baseDirectory
    }

    private let fm = FileManager.default

    func load() -> [ClipboardManager.Item] {
        guard let url = stateURL() else { return [] }
        guard let data = try? Data(contentsOf: url) else { return [] }
        guard let stored = try? JSONDecoder().decode([StoredItem].self, from: data) else { return [] }
        return stored.compactMap { $0.toRuntime(using: self) }
    }

    func save(_ items: [ClipboardManager.Item]) {
        guard let url = stateURL() else { return }
        let stored = items.map { StoredItem(from: $0, using: self) }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        do {
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
        } catch {
            NSLog("JortsMac: failed to persist clipboard: \(error)")
        }
    }

    func clear() {
        if let dir = baseDir() {
            try? fm.removeItem(at: dir)
        }
    }

    // Store images as files to avoid bloating JSON and to keep load fast.
    func saveImageData(_ data: Data, id: UUID) -> String? {
        guard let dir = imagesDir() else { return nil }
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let name = "\(id.uuidString).tiff"
            let url = dir.appendingPathComponent(name)
            try data.write(to: url, options: [.atomic])
            return name
        } catch {
            NSLog("JortsMac: failed to save clipboard image: \(error)")
            return nil
        }
    }

    func loadImageData(named name: String) -> Data? {
        guard let dir = imagesDir() else { return nil }
        let url = dir.appendingPathComponent(name)
        return try? Data(contentsOf: url)
    }

    private func stateURL() -> URL? {
        baseDir()?.appendingPathComponent("clipboard.json")
    }

    private func imagesDir() -> URL? {
        baseDir()?.appendingPathComponent("Images", isDirectory: true)
    }

    private func baseDir() -> URL? {
        // Keep clipboard history alongside notes storage for a "second brain" experience.
        // By default this matches NoteStorage's default: ~/Documents/JortsMacOS.
        if let baseDirectoryOverride {
            return baseDirectoryOverride.appendingPathComponent("Clipboard", isDirectory: true)
        }

        let fm = FileManager.default
        let documentsDirectory = try? fm.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let appFolderName = "JortsMacOS"
        let defaultStorageDirectory = (documentsDirectory ?? fm.homeDirectoryForCurrentUser)
            .appendingPathComponent(appFolderName, isDirectory: true)
        return defaultStorageDirectory.appendingPathComponent("Clipboard", isDirectory: true)
    }
}

private struct StoredItem: Codable {
    let id: UUID
    let createdAt: Date
    let sourceBundleID: String?
    let sourceAppName: String?
    let kind: ClipboardManager.Item.Kind
    let previewText: String

    let payloadText: String?
    let payloadURL: String?
    let payloadImageName: String?
    let payloadFilePaths: [String]?

    init(from item: ClipboardManager.Item, using persistence: ClipboardPersistence) {
        id = item.id
        createdAt = item.createdAt
        sourceBundleID = item.sourceBundleID
        sourceAppName = item.sourceAppName
        kind = item.kind
        previewText = item.previewText

        switch item.payload {
        case .text(let t):
            payloadText = t
            payloadURL = nil
            payloadImageName = nil
            payloadFilePaths = nil
        case .url(let u):
            payloadText = nil
            payloadURL = u.absoluteString
            payloadImageName = nil
            payloadFilePaths = nil
        case .imageData(let data):
            payloadText = nil
            payloadURL = nil
            payloadImageName = persistence.saveImageData(data, id: item.id)
            payloadFilePaths = nil
        case .fileURLs(let urls):
            payloadText = nil
            payloadURL = nil
            payloadImageName = nil
            payloadFilePaths = urls.map { $0.path }
        }
    }

    func toRuntime(using persistence: ClipboardPersistence) -> ClipboardManager.Item? {
        let payload: ClipboardManager.Item.Payload
        switch kind {
        case .text:
            guard let payloadText else { return nil }
            payload = .text(payloadText)
        case .url:
            guard let s = payloadURL, let u = URL(string: s) else { return nil }
            payload = .url(u)
        case .image:
            guard let name = payloadImageName,
                  let data = persistence.loadImageData(named: name) else { return nil }
            payload = .imageData(data)
        case .fileURLs:
            let urls = (payloadFilePaths ?? []).map { URL(fileURLWithPath: $0) }
            guard !urls.isEmpty else { return nil }
            payload = .fileURLs(urls)
        }

        return ClipboardManager.Item(
            id: id,
            createdAt: createdAt,
            sourceBundleID: sourceBundleID,
            sourceAppName: sourceAppName,
            kind: kind,
            previewText: previewText,
            payload: payload
        )
    }
}

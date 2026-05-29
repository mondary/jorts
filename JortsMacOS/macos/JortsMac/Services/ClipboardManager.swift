import AppKit
import Combine

final class ClipboardManager: ObservableObject {
    struct Item: Identifiable, Equatable {
        enum Kind: String, Codable {
            case text
            case url
            case image
            case fileURLs
            case color
        }

        let id: UUID
        let createdAt: Date
        let sourceBundleID: String?
        let sourceAppName: String?
        let kind: Kind
        let previewText: String
        let payload: Payload
        var isPinned: Bool
        var isLocked: Bool
        var isTrashed: Bool
        var tags: [String]
        var metadataTitle: String?
        var metadataDescription: String?
        var metadataFaviconName: String?
        var metadataImageName: String?

        enum Payload: Equatable {
            case text(String)
            case url(URL)
            case imageData(Data)
            case fileURLs([URL])
            case colorHex(String)
        }
    }

    @Published private(set) var items: [Item] = []
    @Published private(set) var drawerPresentationToken: Int = 0

    var isPaused: Bool = false
    var maxItems: Int = 500
    var maxAgeDays: Int = 30
    var sourceMode: ClipboardSourceMode = .allowAll
    var sourceList: Set<String> = []

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
        purgeIfNeeded()
        refreshMissingURLMetadata()
    }

    func refreshMissingURLMetadata(limit: Int = 50) {
        let targets = items
            .filter { item in
                item.kind == .url &&
                (item.metadataTitle == nil || item.metadataDescription == nil || item.metadataImageName == nil)
            }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map(\.id)

        for id in targets {
            Task {
                await fetchMetadata(for: id)
            }
        }
    }

    func start() {
        stop()
        // Polling is reliable across apps without requiring accessibility permissions.
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshMissingURLMetadata(limit: 25)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func clear() {
        items.removeAll()
        persistence.clear()
    }

    func clearTrash() {
        items.removeAll { $0.isTrashed }
        scheduleSave()
    }

    func markDrawerPresented() {
        drawerPresentationToken &+= 1
        refreshMissingURLMetadata(limit: 25)
    }

    func setConfig(maxItems: Int, maxAgeDays: Int, sourceMode: ClipboardSourceMode, sourceList: [String]) {
        self.maxItems = max(50, maxItems)
        self.maxAgeDays = max(1, maxAgeDays)
        self.sourceMode = sourceMode
        self.sourceList = Set(sourceList)
        purgeIfNeeded()
    }

    struct Query {
        enum KindFilter: String, CaseIterable, Identifiable {
            case all
            case text
            case url
            case image
            case file
            case color

            var id: String { rawValue }
        }

        var text: String = ""
        var kind: KindFilter = .all
        var sourceBundleID: String? = nil
        var pinnedOnly: Bool = false
        var recentOnly: Bool = false
        var recentWindowMinutes: Int = 60
        var includeTrashed: Bool = false
    }

    func filteredItems(_ q: Query) -> [Item] {
        let needle = q.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cutoff = Date().addingTimeInterval(-Double(q.recentWindowMinutes) * 60.0)

        return items.filter { item in
            if !q.includeTrashed && item.isTrashed { return false }
            if q.pinnedOnly && !item.isPinned { return false }
            if q.recentOnly && item.createdAt < cutoff { return false }
            if let source = q.sourceBundleID, item.sourceBundleID != source { return false }
            switch q.kind {
            case .all:
                break
            case .text:
                if item.kind != .text { return false }
            case .url:
                if item.kind != .url { return false }
            case .image:
                if item.kind != .image { return false }
            case .file:
                if item.kind != .fileURLs { return false }
            case .color:
                if item.kind != .color { return false }
            }
            if needle.isEmpty { return true }
            if item.previewText.lowercased().contains(needle) { return true }
            if (item.sourceAppName?.lowercased().contains(needle) ?? false) { return true }
            return false
        }
    }

    func togglePin(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isPinned.toggle()
        scheduleSave()
    }

    func toggleLock(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isLocked.toggle()
        scheduleSave()
    }

    func addTag(_ tag: String, to id: UUID) {
        let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, let idx = items.firstIndex(where: { $0.id == id }) else { return }
        if !items[idx].tags.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
            items[idx].tags.append(normalized)
            items[idx].tags.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            scheduleSave()
        }
    }

    func removeTag(_ tag: String, from id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
        scheduleSave()
    }

    func delete(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isTrashed = true
        items[idx].isPinned = false
        scheduleSave()
    }

    func restore(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isTrashed = false
        scheduleSave()
    }

    func deletePermanently(_ id: UUID) {
        items.removeAll { $0.id == id }
        scheduleSave()
    }

    func loadFaviconData(named name: String) -> Data? {
        return persistence.loadFaviconData(named: name)
    }

    func loadURLPreviewImageData(named name: String) -> Data? {
        return persistence.loadURLPreviewImageData(named: name)
    }

    func deleteAll(fromSourceBundleID bundleID: String?) {
        guard let bundleID else { return }
        items.removeAll { $0.sourceBundleID == bundleID && !$0.isLocked }
        scheduleSave()
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
        case .colorHex(let hex):
            pasteboard.clearContents()
            pasteboard.setString(hex, forType: .string)
        }
        // This write is initiated by the clipboard drawer itself. Treat the new
        // pasteboard change count as already observed so polling does not create
        // a duplicate tile with the same content.
        lastChangeCount = pasteboard.changeCount
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

        if shouldIgnoreSource(bundleID: bundleID) {
            return
        }

        // Prefer file URLs, then images, then string.
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty
        {
            // If user copied an image file from Finder, prefer an actual image preview.
            if urls.count == 1, let data = tryLoadImageFileDataIfPossible(urls[0]) {
                append(Item(
                    id: UUID(),
                    createdAt: Date(),
                    sourceBundleID: bundleID,
                    sourceAppName: appName,
                    kind: .image,
                    previewText: urls[0].lastPathComponent,
                    payload: .imageData(data),
                    isPinned: false,
                    isLocked: false,
                    isTrashed: false,
                    tags: [],
                    metadataTitle: nil,
                    metadataDescription: nil,
                    metadataFaviconName: nil,
                    metadataImageName: nil
                ))
            } else {
                let preview = urls.first?.lastPathComponent ?? "Files"
                append(Item(
                    id: UUID(),
                    createdAt: Date(),
                    sourceBundleID: bundleID,
                    sourceAppName: appName,
                    kind: .fileURLs,
                    previewText: preview,
                    payload: .fileURLs(urls),
                    isPinned: false,
                    isLocked: false,
                    isTrashed: false,
                    tags: [],
                    metadataTitle: nil,
                    metadataDescription: nil,
                    metadataFaviconName: nil,
                    metadataImageName: nil
                ))
            }
            return
        }

        // Images: robust extraction across apps (web, design tools, Finder, etc.)
        if let imageData = extractImageData(from: pasteboard) {
            append(Item(
                id: UUID(),
                createdAt: Date(),
                sourceBundleID: bundleID,
                sourceAppName: appName,
                kind: .image,
                previewText: "Image",
                payload: .imageData(imageData),
                isPinned: false,
                isLocked: false,
                isTrashed: false,
                tags: [],
                metadataTitle: nil,
                metadataDescription: nil,
                metadataFaviconName: nil,
                metadataImageName: nil
            ))
            return
        }

            if let s = pasteboard.string(forType: .string), !s.isEmpty {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if let colorHex = Self.normalizedHexColor(trimmed) {
                append(Item(
                    id: UUID(),
                    createdAt: Date(),
                    sourceBundleID: bundleID,
                    sourceAppName: appName,
                    kind: .color,
                    previewText: colorHex,
                    payload: .colorHex(colorHex),
                    isPinned: false,
                    isLocked: false,
                    isTrashed: false,
                    tags: [],
                    metadataTitle: nil,
                    metadataDescription: nil,
                    metadataFaviconName: nil,
                    metadataImageName: nil
                ))
            } else if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
                append(Item(
                    id: UUID(),
                    createdAt: Date(),
                    sourceBundleID: bundleID,
                    sourceAppName: appName,
                    kind: .url,
                    previewText: trimmed,
                    payload: .url(url),
                    isPinned: false,
                    isLocked: false,
                    isTrashed: false,
                    tags: [],
                    metadataTitle: nil,
                    metadataDescription: nil,
                    metadataFaviconName: nil,
                    metadataImageName: nil
                ))
            } else {
                append(Item(
                    id: UUID(),
                    createdAt: Date(),
                    sourceBundleID: bundleID,
                    sourceAppName: appName,
                    kind: .text,
                    previewText: String(trimmed.prefix(240)),
                    payload: .text(s),
                    isPinned: false,
                    isLocked: false,
                    isTrashed: false,
                    tags: [],
                    metadataTitle: nil,
                    metadataDescription: nil,
                    metadataFaviconName: nil,
                    metadataImageName: nil
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

        // Keep pinned items at the top, then newest items.
        let insertionIndex = items.firstIndex(where: { !$0.isPinned }) ?? items.count
        items.insert(item, at: insertionIndex)
        purgeIfNeeded()
        scheduleSave()

        if item.kind == .url {
            Task {
                await fetchMetadata(for: item.id)
            }
        }
    }

    private func fetchMetadata(for id: UUID) async {
        guard let item = items.first(where: { $0.id == id }),
              case .url(let url) = item.payload else { return }

        guard let metadata = await URLPreviewService.shared.fetchMetadata(for: url) else { return }

        await MainActor.run {
            guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
            var updatedItem = items[idx]
            updatedItem.metadataTitle = metadata.title
            updatedItem.metadataDescription = metadata.description
            if let faviconData = metadata.faviconData {
                updatedItem.metadataFaviconName = persistence.saveFaviconData(faviconData, id: id)
            }
            if let imageData = metadata.imageData {
                updatedItem.metadataImageName = persistence.saveURLPreviewImageData(imageData, id: id)
            }
            items[idx] = updatedItem
            scheduleSave()
        }
    }

    private func frontmostAppIdentity() -> (bundleID: String?, name: String?) {
        let app = NSWorkspace.shared.frontmostApplication
        return (app?.bundleIdentifier, app?.localizedName)
    }

    private func tryLoadImageFileDataIfPossible(_ url: URL) -> Data? {
        let ext = url.pathExtension.lowercased()
        let likelyImage = ["png", "jpg", "jpeg", "gif", "webp", "tiff", "heic", "heif"].contains(ext)
        guard likelyImage else { return nil }
        if let img = NSImage(contentsOf: url), let tiff = img.tiffRepresentation, !tiff.isEmpty {
            return tiff
        }
        return nil
    }

    private static func normalizedHexColor(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return nil }
        let raw = String(trimmed.dropFirst())
        guard raw.count == 3 || raw.count == 6 || raw.count == 8 else { return nil }
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard raw.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }

        if raw.count == 3 {
            let expanded = raw.map { "\($0)\($0)" }.joined()
            return "#\(expanded.uppercased())"
        }
        return "#\(raw.uppercased())"
    }

    private func extractImageData(from pasteboard: NSPasteboard) -> Data? {
        // 1) Try AppKit bridge (handles many representations)
        if let img = NSImage(pasteboard: pasteboard),
           let tiff = img.tiffRepresentation, !tiff.isEmpty
        {
            return tiff
        }

        // 2) Try explicit data representations on pasteboard items
        let candidates: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType(rawValue: "public.png"),
            NSPasteboard.PasteboardType(rawValue: "public.jpeg"),
            NSPasteboard.PasteboardType(rawValue: "public.jpg"),
            NSPasteboard.PasteboardType(rawValue: "public.tiff")
        ]

        if let items = pasteboard.pasteboardItems {
            for it in items {
                for t in candidates where it.types.contains(t) {
                    if let d = it.data(forType: t), !d.isEmpty {
                        return d
                    }
                }
            }
        }

        // 3) Fallback direct read by type
        for t in candidates {
            if let d = pasteboard.data(forType: t), !d.isEmpty {
                return d
            }
        }

        if let types = pasteboard.types, !types.isEmpty {
            let joined = types.map { $0.rawValue }.joined(separator: ", ")
            NSLog("PKbrain: no image extracted; pasteboard types: %@", joined)
        }
        return nil
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

    private func shouldIgnoreSource(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        switch sourceMode {
        case .allowAll:
            return false
        case .blockList:
            return sourceList.contains(bundleID)
        case .allowList:
            return !sourceList.contains(bundleID)
        }
    }

    private func purgeIfNeeded() {
        // 1) Age-based purge for non-locked items.
        let cutoff = Date().addingTimeInterval(-Double(maxAgeDays) * 86400.0)
        items.removeAll { item in
            guard !item.isLocked else { return false }
            return item.createdAt < cutoff
        }

        // 2) Count-based purge for non-pinned/non-locked oldest items.
        if items.count > maxItems {
            // Keep pinned + locked regardless.
            var keep: [Item] = items.filter { $0.isPinned || $0.isLocked }
            let rest = items.filter { !$0.isPinned && !$0.isLocked }
            let remainingSlots = max(0, maxItems - keep.count)
            keep.append(contentsOf: rest.prefix(remainingSlots))
            items = keep
        }
    }
}

// MARK: - Persistence

final class ClipboardPersistence {
    static let shared = ClipboardPersistence(baseDirectory: nil)

    // If nil, we fall back to the default NoteStorage location (Documents/PKbrain).
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
            cleanupOrphanedFiles(
                validImageNames: Set(stored.compactMap { $0.payloadImageName }),
                validFaviconNames: Set(stored.compactMap { $0.metadataFaviconName })
            )
        } catch {
            NSLog("PKbrain: failed to persist clipboard: \(error)")
        }
    }

    private func cleanupOrphanedFiles(validImageNames: Set<String>, validFaviconNames: Set<String>) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            if let imagesDir = self.imagesDir(), let files = try? self.fm.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil) {
                for file in files {
                    if !validImageNames.contains(file.lastPathComponent) {
                        try? self.fm.removeItem(at: file)
                    }
                }
            }
            
            if let faviconsDir = self.faviconsDir(), let files = try? self.fm.contentsOfDirectory(at: faviconsDir, includingPropertiesForKeys: nil) {
                for file in files {
                    if !validFaviconNames.contains(file.lastPathComponent) {
                        try? self.fm.removeItem(at: file)
                    }
                }
            }
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
            NSLog("PKbrain: failed to save clipboard image: \(error)")
            return nil
        }
    }

    func loadImageData(named name: String) -> Data? {
        guard let dir = imagesDir() else { return nil }
        let url = dir.appendingPathComponent(name)
        return try? Data(contentsOf: url)
    }

    func saveFaviconData(_ data: Data, id: UUID) -> String? {
        guard let dir = faviconsDir() else { return nil }
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let name = "\(id.uuidString).png"
            let url = dir.appendingPathComponent(name)
            try data.write(to: url, options: [.atomic])
            return name
        } catch {
            NSLog("PKbrain: failed to save favicon: \(error)")
            return nil
        }
    }

    func loadFaviconData(named name: String) -> Data? {
        guard let dir = faviconsDir() else { return nil }
        let url = dir.appendingPathComponent(name)
        return try? Data(contentsOf: url)
    }

    func saveURLPreviewImageData(_ data: Data, id: UUID) -> String? {
        guard let dir = urlPreviewsDir() else { return nil }
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let name = "\(id.uuidString).image"
            let url = dir.appendingPathComponent(name)
            try data.write(to: url, options: [.atomic])
            return name
        } catch {
            NSLog("PKbrain: failed to save URL preview image: \(error)")
            return nil
        }
    }

    func loadURLPreviewImageData(named name: String) -> Data? {
        guard let dir = urlPreviewsDir() else { return nil }
        let url = dir.appendingPathComponent(name)
        return try? Data(contentsOf: url)
    }

    private func stateURL() -> URL? {
        baseDir()?.appendingPathComponent("clipboard.json")
    }

    private func imagesDir() -> URL? {
        baseDir()?.appendingPathComponent("Images", isDirectory: true)
    }

    private func faviconsDir() -> URL? {
        baseDir()?.appendingPathComponent("Favicons", isDirectory: true)
    }

    private func urlPreviewsDir() -> URL? {
        baseDir()?.appendingPathComponent("URLPreviews", isDirectory: true)
    }

    private func baseDir() -> URL? {
        // Keep clipboard history alongside notes storage for a "second brain" experience.
        // By default this matches NoteStorage's default: ~/Documents/PKbrain.
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

        let appFolderName = "PKbrain"
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
    let isPinned: Bool
    let isLocked: Bool
    let isTrashed: Bool?
    let tags: [String]?
    let metadataTitle: String?
    let metadataDescription: String?
    let metadataFaviconName: String?
    let metadataImageName: String?

    let payloadText: String?
    let payloadURL: String?
    let payloadImageName: String?
    let payloadFilePaths: [String]?
    let payloadColorHex: String?

    init(from item: ClipboardManager.Item, using persistence: ClipboardPersistence) {
        id = item.id
        createdAt = item.createdAt
        sourceBundleID = item.sourceBundleID
        sourceAppName = item.sourceAppName
        kind = item.kind
        previewText = item.previewText
        isPinned = item.isPinned
        isLocked = item.isLocked
        isTrashed = item.isTrashed
        tags = item.tags
        metadataTitle = item.metadataTitle
        metadataDescription = item.metadataDescription
        metadataFaviconName = item.metadataFaviconName
        metadataImageName = item.metadataImageName

        switch item.payload {
        case .text(let t):
            payloadText = t
            payloadURL = nil
            payloadImageName = nil
            payloadFilePaths = nil
            payloadColorHex = nil
        case .url(let u):
            payloadText = nil
            payloadURL = u.absoluteString
            payloadImageName = nil
            payloadFilePaths = nil
            payloadColorHex = nil
        case .imageData(let data):
            payloadText = nil
            payloadURL = nil
            payloadImageName = persistence.saveImageData(data, id: item.id)
            payloadFilePaths = nil
            payloadColorHex = nil
        case .fileURLs(let urls):
            payloadText = nil
            payloadURL = nil
            payloadImageName = nil
            payloadFilePaths = urls.map { $0.path }
            payloadColorHex = nil
        case .colorHex(let hex):
            payloadText = nil
            payloadURL = nil
            payloadImageName = nil
            payloadFilePaths = nil
            payloadColorHex = hex
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
        case .color:
            guard let payloadColorHex else { return nil }
            payload = .colorHex(payloadColorHex)
        }

        return ClipboardManager.Item(
            id: id,
            createdAt: createdAt,
            sourceBundleID: sourceBundleID,
            sourceAppName: sourceAppName,
            kind: kind,
            previewText: previewText,
            payload: payload,
            isPinned: isPinned,
            isLocked: isLocked,
            isTrashed: isTrashed ?? false,
            tags: tags ?? [],
            metadataTitle: metadataTitle,
            metadataDescription: metadataDescription,
            metadataFaviconName: metadataFaviconName,
            metadataImageName: metadataImageName
        )
    }
}

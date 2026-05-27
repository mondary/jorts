import SwiftUI

struct ClipboardView: View {
    @ObservedObject var clipboard: ClipboardManager
    let onCreateNoteFromItem: (ClipboardManager.Item) -> Void
    let onCopyItem: (ClipboardManager.Item) -> Void
    let onDismiss: () -> Void
    let onPaste: () -> Void

    @State private var query: String = ""
    @State private var selectedSource: String? = nil
    @State private var selectedID: UUID?
    private let deckScale: CGFloat = 0.70
    @State private var kind: ClipboardManager.Query.KindFilter = .all
    @State private var pinnedOnly: Bool = false
    @State private var recentOnly: Bool = false
    @State private var recentMinutes: Int = 60
    @State private var showExportPanel: Bool = false
    @State private var lightboxImage: NSImage?
    @State private var quickLookURLs: [URL] = []
    @FocusState private var searchFocused: Bool
    @State private var keyMonitor: Any?

    var body: some View {
        ZStack {
            VibrancyBackground()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                topRow
                bottomBar
            }
            .padding(.top, 18)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(minWidth: 900, minHeight: 420)
        .onAppear { installKeyMonitorIfNeeded() }
        .onDisappear { removeKeyMonitorIfNeeded() }
    }

    private var topRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                ForEach(filteredItems) { item in
                    DeckCard(
                        item: item,
                        isSelected: selectedID == item.id,
                        onSelect: { selectedID = item.id },
                        onCopy: { onCopyItem(item) },
                        onMakeNote: { onCreateNoteFromItem(item) },
                        scale: deckScale,
                        onDelete: { clipboard.delete(item.id) },
                        onTogglePin: { clipboard.togglePin(item.id) },
                        onToggleLock: { clipboard.toggleLock(item.id) },
                        onQuickLook: { urls in quickLookURLs = urls },
                        onLightbox: { img in lightboxImage = img },
                        onLoadFavicon: { name in clipboard.loadFaviconData(named: name) }
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 390 * deckScale)
        .onAppear {
            if selectedID == nil {
                selectedID = filteredItems.first?.id
            }
        }
        .sheet(isPresented: Binding(
            get: { !quickLookURLs.isEmpty },
            set: { if !$0 { quickLookURLs = [] } }
        )) {
            QuickLookPreview(urls: quickLookURLs)
                .frame(minWidth: 820, minHeight: 520)
        }
        .sheet(item: Binding<LightboxImage?>(
            get: {
                guard let img = lightboxImage else { return nil }
                return LightboxImage(image: img)
            },
            set: { _, _ in lightboxImage = nil }
        )) { (item: LightboxImage) in
            Image(nsImage: item.image)
                .resizable()
                .scaledToFit()
                .padding(20)
                .frame(minWidth: 600, minHeight: 400)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { !clipboard.isPaused },
                set: { clipboard.isPaused = !$0 }
            )) {
                Text(localizedString("clipboard_capture"))
                    .font(.subheadline.weight(.medium))
            }
            .toggleStyle(.switch)

            TextField(localizedString("search"), text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)
                .focused($searchFocused)

            Picker("", selection: $kind) {
                Text(localizedString("filter_all")).tag(ClipboardManager.Query.KindFilter.all)
                Text(localizedString("filter_text")).tag(ClipboardManager.Query.KindFilter.text)
                Text(localizedString("filter_url")).tag(ClipboardManager.Query.KindFilter.url)
                Text(localizedString("filter_image")).tag(ClipboardManager.Query.KindFilter.image)
                Text(localizedString("filter_files")).tag(ClipboardManager.Query.KindFilter.file)
            }
            .frame(width: 160)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SourceChip(
                        title: localizedString("all_sources"),
                        isSelected: selectedSource == nil,
                        icon: nil
                    ) { selectedSource = nil }

                    ForEach(sourceChips, id: \.bundleID) { chip in
                        SourceChip(
                            title: chip.name,
                            isSelected: selectedSource == chip.name,
                            icon: chip.icon
                        ) { selectedSource = chip.name }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxWidth: 420)

            Toggle(localizedString("pinned"), isOn: $pinnedOnly)
                .toggleStyle(.checkbox)

            Toggle(localizedString("recent"), isOn: $recentOnly)
                .toggleStyle(.checkbox)

            Spacer()

            Button {
                showExportPanel = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(localizedString("export"))

            Button {
                clipboard.clear()
            } label: {
                Image(systemName: "trash")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(localizedString("clear"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.20))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private var sources: [String] {
        Array(Set(clipboard.items.compactMap { $0.sourceAppName })).sorted()
    }

    private var sourceChips: [SourceChipModel] {
        let items = clipboard.items
        var byBundle: [String: SourceChipModel] = [:]
        for it in items {
            guard let bid = it.sourceBundleID else { continue }
            let name = it.sourceAppName ?? localizedString("unknown_source")
            if byBundle[bid] == nil {
                byBundle[bid] = SourceChipModel(bundleID: bid, name: name, icon: appIcon(bundleID: bid))
            }
        }
        return Array(byBundle.values).sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var filteredItems: [ClipboardManager.Item] {
        let sourceBundleID: String?
        if let selectedSource {
            let firstMatch = clipboard.items.first(where: { $0.sourceAppName == selectedSource })
            sourceBundleID = firstMatch?.sourceBundleID
        } else {
            sourceBundleID = nil
        }

        let q = ClipboardManager.Query(
            text: query,
            kind: kind,
            sourceBundleID: sourceBundleID,
            pinnedOnly: pinnedOnly,
            recentOnly: recentOnly,
            recentWindowMinutes: recentMinutes
        )
        return clipboard.filteredItems(q)
    }


    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handleKeyDown(event) ? nil : event
        }
    }

    private func removeKeyMonitorIfNeeded() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        // Only handle when the clipboard drawer is frontmost.
        guard NSApp.isActive else { return false }

        // Esc closes.
        if event.keyCode == 53 { // kVK_Escape
            onDismiss()
            return true
        }

        // Cmd+F focuses search.
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "f"
        {
            searchFocused = true
            return true
        }

        let items = filteredItems
        guard !items.isEmpty else { return false }
        if selectedID == nil { selectedID = items.first?.id }

        // Left / Right arrows: move through the horizontal list.
        if event.keyCode == 123 || event.keyCode == 124 { // left/right
            let delta = (event.keyCode == 123) ? -1 : 1
            moveSelection(delta: delta, items: items)
            return true
        }

        // Enter / Return: copy. Cmd+Enter: convert to note.
        if event.keyCode == 36 || event.keyCode == 76 { // return / enter
            guard let id = selectedID, let item = items.first(where: { $0.id == id }) else { return true }
            if event.modifierFlags.contains(.command) {
                onCreateNoteFromItem(item)
            } else {
                onCopyItem(item)
                onPaste()
            }
            return true
        }

        return false
    }

    private func moveSelection(delta: Int, items: [ClipboardManager.Item]) {
        guard let id = selectedID, let idx = items.firstIndex(where: { $0.id == id }) else {
            selectedID = items.first?.id
            return
        }
        let next = max(0, min(items.count - 1, idx + delta))
        selectedID = items[next].id
    }
}

private struct SourceChipModel {
    let bundleID: String
    let name: String
    let icon: NSImage?
}

private func appIcon(bundleID: String) -> NSImage? {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    return nil
}

private struct SourceChip: View {
    let title: String
    let isSelected: Bool
    let icon: NSImage?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.white.opacity(0.55) : Color.white.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(isSelected ? 0.35 : 0.18), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DeckCard: View {
    let item: ClipboardManager.Item
    let isSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onMakeNote: () -> Void
    let scale: CGFloat
    let onDelete: (() -> Void)?
    let onTogglePin: (() -> Void)?
    let onToggleLock: (() -> Void)?
    let onQuickLook: (([URL]) -> Void)?
    let onLightbox: ((NSImage) -> Void)?
    let onLoadFavicon: (String) -> Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AppIconView(bundleID: item.sourceBundleID)
                    .frame(width: 22 * scale, height: 22 * scale)
                Text("⌘1")
                    .font(.system(size: 14 * scale, weight: .medium))
                    .foregroundStyle(Color(red: 0/255, green: 122/255, blue: 255/255))
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12 * scale, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                if item.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12 * scale, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(relativeTime(item.createdAt))
                    .font(.system(size: 11 * scale, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            preview

            if item.kind != .url {
                Text(item.metadataTitle ?? item.previewText)
                    .font(.system(size: 15 * scale, weight: item.metadataTitle != nil ? .medium : .regular))
                    .foregroundStyle(Color(NSColor.labelColor))
                    .lineLimit(12)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if item.metadataTitle != nil {
                    Text(item.previewText)
                        .font(.system(size: 12 * scale, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if item.metadataTitle == nil && item.metadataFaviconName == nil {
                Text(item.previewText)
                    .font(.system(size: 15 * scale, weight: .regular))
                    .foregroundStyle(Color(NSColor.labelColor))
                    .lineLimit(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Text(metaText)
                    .font(.system(size: 11 * scale))
                    .foregroundStyle(.secondary)
                Spacer()

                Button {
                    onTogglePin?()
                } label: {
                    Image(systemName: item.isPinned ? "pin.slash" : "pin")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .frame(width: 34 * scale, height: 34 * scale)
                }
                .buttonStyle(.plain)
                .help(localizedString("pin"))

                Button {
                    onToggleLock?()
                } label: {
                    Image(systemName: item.isLocked ? "lock.open" : "lock")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .frame(width: 34 * scale, height: 34 * scale)
                }
                .buttonStyle(.plain)
                .help(localizedString("lock"))

                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .frame(width: 34 * scale, height: 34 * scale)
                }
                .buttonStyle(.plain)
                .help(localizedString("copy"))

                Button(action: onMakeNote) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .frame(width: 34 * scale, height: 34 * scale)
                }
                .buttonStyle(.plain)
                .help(localizedString("convert_to_note"))

                Button {
                    onDelete?()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .frame(width: 34 * scale, height: 34 * scale)
                }
                .buttonStyle(.plain)
                .help(localizedString("delete"))
            }
        }
        .padding(18 * scale)
        .frame(width: 320 * scale, height: 370 * scale)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color(red: 0/255, green: 122/255, blue: 255/255) : Color(NSColor.separatorColor).opacity(0.25), lineWidth: isSelected ? 3 : 1)
        )
        .shadow(color: Color.black.opacity(isSelected ? 0.10 : 0.04), radius: isSelected ? 18 : 14, x: 0, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture {
            onSelect()
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch item.payload {
        case .imageData(let data):
            if let image = NSImage(data: data) {
                GeometryReader { geo in
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                        .clipped()
                }
                .frame(height: 120 * scale)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 1)
                )
                .onTapGesture {
                    onLightbox?(image)
                }
            }
        case .fileURLs(let urls):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(urls.prefix(3), id: \.self) { url in
                    HStack(spacing: 8) {
                        FileIconView(url: url)
                            .frame(width: 18 * scale, height: 18 * scale)
                        Text(url.lastPathComponent)
                            .font(.system(size: 12 * scale))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                if urls.count > 3 {
                    Text("+ \(urls.count - 3)")
                        .font(.system(size: 11 * scale))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10 * scale)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .onTapGesture {
                onQuickLook?(urls)
            }
        case .url(let url):
            HStack(spacing: 12) {
                if let faviconName = item.metadataFaviconName,
                   let faviconData = onLoadFavicon(faviconName),
                   let image = NSImage(data: faviconData) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32 * scale, height: 32 * scale)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.controlBackgroundColor))
                        Image(systemName: "globe")
                            .font(.system(size: 16 * scale))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 32 * scale, height: 32 * scale)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor).opacity(0.2), lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.metadataTitle ?? url.host ?? localizedString("link"))
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .foregroundColor(Color(NSColor.labelColor))
                        .lineLimit(2)

                    Text(url.host ?? url.absoluteString)
                        .font(.system(size: 11 * scale))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.1), lineWidth: 1)
            )
        default:
            EmptyView()
        }
    }

    private var iconName: String {
        switch item.kind {
        case .text: return "text.quote"
        case .url: return "link"
        case .image: return "photo"
        case .fileURLs: return "doc"
        }
    }

    private var metaText: String {
        switch item.payload {
        case .text(let t):
            return "\(t.count) \(localizedString("characters"))"
        case .url:
            return localizedString("link")
        case .imageData:
            return localizedString("image")
        case .fileURLs(let urls):
            return "\(urls.count) \(localizedString("files"))"
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct AppIconView: View {
    let bundleID: String?

    var body: some View {
        if let img = appIcon() {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    Image(systemName: "app")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                )
        }
    }

    private func appIcon() -> NSImage? {
        guard let bundleID else { return nil }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }
}

private struct FileIconView: View {
    let url: URL

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct VibrancyBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct LightboxImage: Identifiable {
    let id = UUID()
    let image: NSImage
}

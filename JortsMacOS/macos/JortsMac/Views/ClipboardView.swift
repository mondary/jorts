import SwiftUI

struct ClipboardView: View {
    struct NoteDeckItem: Identifiable, Equatable {
        let id: UUID
        let title: String
        let content: String
        let theme: NoteTheme
        let isPinned: Bool
        let updatedAt: Date
    }

    @ObservedObject var clipboard: ClipboardManager
    let notesProvider: () -> [NoteDeckItem]
    let onCreateNoteFromItem: (ClipboardManager.Item) -> Void
    let onOpenNote: (UUID) -> Void
    let onCopyItem: (ClipboardManager.Item) -> Void
    let onDismiss: () -> Void
    let onPaste: () -> Void
    let shouldHandleKeyboard: () -> Bool
    let onContextStateChanged: (Bool) -> Void

    @State private var query: String = ""
    @State private var selectedSource: SourceFilter = .all
    @State private var selectedID: UUID?
    private let deckScale: CGFloat = 0.82
    @State private var kind: ClipboardManager.Query.KindFilter = .all
    @State private var pinnedOnly: Bool = false
    @State private var recentOnly: Bool = false
    @State private var recentMinutes: Int = 60
    @State private var showExportPanel: Bool = false
    @State private var lightboxImage: NSImage?
    @State private var quickLookURLs: [URL] = []
    @FocusState private var searchFocused: Bool
    @State private var keyMonitor: Any?

    private enum DeckEntry: Identifiable, Equatable {
        case clipboard(ClipboardManager.Item)
        case note(NoteDeckItem)

        var id: UUID {
            switch self {
            case .clipboard(let item): return item.id
            case .note(let item): return item.id
            }
        }
    }

    private enum SourceFilter: Equatable {
        case all
        case notes
        case app(String)
    }

    var body: some View {
        ZStack {
            VibrancyBackground()
                .ignoresSafeArea()

            VStack(spacing: 10) {
                topRow
                bottomBar
            }
            .padding(.top, 0)
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 12,
                topTrailingRadius: 0
            )
        )
        .frame(minWidth: 900, minHeight: 420)
        .onAppear {
            installKeyMonitorIfNeeded()
            notifyContextState()
        }
        .onDisappear { removeKeyMonitorIfNeeded() }
        .onReceive(clipboard.$drawerPresentationToken) { _ in
            resetContextToLatestClipboard()
        }
        .onChange(of: contextSignature) { _ in
            notifyContextState()
        }
    }

    @ViewBuilder
    private var topRow: some View {
        let entries = filteredEntries
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(entries) { entry in
                        switch entry {
                        case .clipboard(let item):
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
                                onLoadFavicon: { name in clipboard.loadFaviconData(named: name) },
                                onLoadURLPreviewImage: { name in clipboard.loadURLPreviewImageData(named: name) }
                            )
                            .id(item.id)
                        case .note(let note):
                            NoteDeckCard(
                                note: note,
                                isSelected: selectedID == note.id,
                                scale: deckScale,
                                onSelect: { selectedID = note.id },
                                onOpen: { onOpenNote(note.id) }
                            )
                            .id(note.id)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 340)
            .onAppear {
                if selectedID == nil || !entries.contains(where: { $0.id == selectedID }) {
                    selectedID = entries.first?.id
                }
                scrollSelectionIntoView(proxy: proxy)
            }
            .onChange(of: selectedID) { _ in
                scrollSelectionIntoView(proxy: proxy)
            }
            .onChange(of: entries.map(\.id)) { ids in
                if let selectedID, ids.contains(selectedID) {
                    scrollSelectionIntoView(proxy: proxy)
                } else {
                    selectedID = ids.first
                }
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

    private func scrollSelectionIntoView(proxy: ScrollViewProxy) {
        guard let selectedID else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.12)) {
                proxy.scrollTo(selectedID, anchor: .center)
            }
        }
    }

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SourceChip(
                        title: localizedString("all_sources"),
                        isSelected: selectedSource == .all,
                        icon: nil
                    ) { selectedSource = .all }

                    SourceChip(
                        title: localizedString("notes"),
                        isSelected: selectedSource == .notes,
                        icon: notesSourceIcon
                    ) { selectedSource = .notes }

                    ForEach(sourceChips, id: \.bundleID) { chip in
                        SourceChip(
                            title: chip.name,
                            isSelected: selectedSource == .app(chip.bundleID),
                            icon: chip.icon
                        ) { selectedSource = .app(chip.bundleID) }
                    }
                }
                .padding(.vertical, 2)
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity)

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
                Text(localizedString("filter_color")).tag(ClipboardManager.Query.KindFilter.color)
            }
            .frame(width: 160)

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
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.20))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
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

    private var notesSourceIcon: NSImage? {
        NSApp.applicationIconImage
    }

    private var filteredItems: [ClipboardManager.Item] {
        let sourceBundleID: String?
        if case let .app(bundleID) = selectedSource {
            sourceBundleID = bundleID
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

    private var filteredEntries: [DeckEntry] {
        var entries: [DeckEntry] = []
        if selectedSource != .notes {
            entries = filteredItems.map { .clipboard($0) }
        }

        let notes = notesProvider()
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        for note in notes {
            if pinnedOnly && !note.isPinned { continue }
            if recentOnly && note.updatedAt < Date().addingTimeInterval(-Double(recentMinutes) * 60.0) { continue }
            if kind != .all && kind != .text { continue }

            if selectedSource == .all || selectedSource == .notes {
                // allowed
            } else {
                continue
            }
            if !needle.isEmpty {
                let haystack = "\(note.title)\n\(note.content)".lowercased()
                if !haystack.contains(needle) { continue }
            }
            entries.append(.note(note))
        }
        return entries
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
        // The SwiftUI root view can stay alive after the panel is hidden, so the
        // local monitor must be scoped to the visible clipboard drawer only.
        guard shouldHandleKeyboard() else { return false }

        let entries = filteredEntries
        guard !entries.isEmpty else { return false }
        if selectedID == nil { selectedID = entries.first?.id }

        // Left / Right arrows: move through the horizontal list.
        if event.keyCode == 123 || event.keyCode == 124 { // left/right
            let delta = (event.keyCode == 123) ? -1 : 1
            moveSelection(delta: delta, entries: entries)
            return true
        }

        // Cmd+F focuses search.
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "f"
        {
            searchFocused = true
            return true
        }

        if !searchFocused, let typed = searchText(from: event) {
            query.append(typed)
            searchFocused = true
            return true
        }

        if event.modifierFlags.contains(.command),
           let quickIndex = quickSlotIndex(for: event.keyCode),
           quickIndex < min(9, entries.count)
        {
            let entry = entries[quickIndex]
            selectedID = entry.id
            performPrimaryAction(for: entry)
            return true
        }

        // Enter / Return: copy. Cmd+Enter: convert to note.
        if event.keyCode == 36 || event.keyCode == 76 { // return / enter
            guard let id = selectedID, let entry = entries.first(where: { $0.id == id }) else { return true }
            if event.modifierFlags.contains(.command) {
                if case .clipboard(let item) = entry {
                    onCreateNoteFromItem(item)
                }
            } else {
                performPrimaryAction(for: entry)
            }
            return true
        }

        return false
    }

    private var latestClipboardID: UUID? {
        clipboard.items.max { lhs, rhs in
            lhs.createdAt < rhs.createdAt
        }?.id
    }

    private var defaultSelectionID: UUID? {
        latestClipboardID ?? filteredEntries.first?.id
    }

    private var isDefaultContextOnLatestClipboard: Bool {
        query.isEmpty &&
        selectedSource == .all &&
        kind == .all &&
        pinnedOnly == false &&
        recentOnly == false &&
        selectedID == defaultSelectionID
    }

    private var contextSignature: String {
        [
            query,
            sourceContextKey,
            kind.rawValue,
            pinnedOnly ? "pinned" : "unpinned",
            recentOnly ? "recent" : "all-time",
            selectedID?.uuidString ?? "nil",
            defaultSelectionID?.uuidString ?? "nil"
        ].joined(separator: "|")
    }

    private var sourceContextKey: String {
        switch selectedSource {
        case .all:
            return "all"
        case .notes:
            return "notes"
        case .app(let bundleID):
            return "app:\(bundleID)"
        }
    }

    private func notifyContextState() {
        onContextStateChanged(isDefaultContextOnLatestClipboard)
    }

    private func resetContextToLatestClipboard() {
        query = ""
        selectedSource = .all
        kind = .all
        pinnedOnly = false
        recentOnly = false
        searchFocused = false

        let targetID = defaultSelectionID
        DispatchQueue.main.async {
            self.selectedID = targetID
            self.notifyContextState()
        }
    }

    private func searchText(from event: NSEvent) -> String? {
        // Ignore navigation/function keys.
        switch event.keyCode {
        case 123, 124, 125, 126, 36, 76, 48, 53: // arrows, return, tab, escape
            return nil
        default:
            break
        }
        let flags = event.modifierFlags.intersection([.command, .control, .option])
        guard flags.isEmpty else { return nil }
        guard let chars = event.characters, !chars.isEmpty else { return nil }
        guard chars.rangeOfCharacter(from: .newlines) == nil else { return nil }
        guard chars.rangeOfCharacter(from: .controlCharacters) == nil else { return nil }
        return chars
    }

    private func moveSelection(delta: Int, entries: [DeckEntry]) {
        guard let id = selectedID, let idx = entries.firstIndex(where: { $0.id == id }) else {
            selectedID = entries.first?.id
            return
        }
        let next = max(0, min(entries.count - 1, idx + delta))
        selectedID = entries[next].id
    }

    private func quickSlotIndex(for keyCode: UInt16) -> Int? {
        switch keyCode {
        case 18: return 0 // 1
        case 19: return 1 // 2
        case 20: return 2 // 3
        case 21: return 3 // 4
        case 23: return 4 // 5
        case 22: return 5 // 6
        case 26: return 6 // 7
        case 28: return 7 // 8
        case 25: return 8 // 9
        default: return nil
        }
    }

    private func performPrimaryAction(for entry: DeckEntry) {
        switch entry {
        case .clipboard(let item):
            onCopyItem(item)
            onPaste()
        case .note(let note):
            onOpenNote(note.id)
        }
    }
}

private struct NoteDeckCard: View {
    let note: ClipboardView.NoteDeckItem
    let isSelected: Bool
    let scale: CGFloat
    let onSelect: () -> Void
    let onOpen: () -> Void

    private let cardWidth: CGFloat = 300
    private let cardHeight: CGFloat = 250

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 14 * scale, weight: .semibold))
                    .foregroundStyle(note.theme.autoTextColorColor.opacity(0.9))
                Text(localizedString("notes"))
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundStyle(note.theme.autoTextColorColor.opacity(0.9))
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 12 * scale, weight: .semibold))
                        .foregroundStyle(note.theme.autoTextColorColor.opacity(0.75))
                }
                Spacer()
            }

            Text(note.title.isEmpty ? localizedString("empty_note") : note.title)
                .font(.system(size: 15 * scale, weight: .semibold))
                .foregroundStyle(note.theme.autoTextColorColor)
                .lineLimit(2)

            Text(note.content)
                .font(.system(size: 13 * scale))
                .foregroundStyle(note.theme.autoTextColorColor.opacity(0.9))
                .lineLimit(8)

            Spacer(minLength: 0)

            HStack {
                Text(localizedString("note"))
                    .font(.system(size: 11 * scale))
                    .foregroundStyle(note.theme.autoTextColorColor.opacity(0.75))
                Spacer()
                Button(action: onOpen) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(note.theme.autoTextColorColor.opacity(0.9))
                .help(localizedString("open"))
            }
        }
        .padding(14)
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(note.theme.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color(red: 0/255, green: 122/255, blue: 255/255) : note.theme.autoTextColorColor.opacity(0.2), lineWidth: isSelected ? 3 : 1)
        )
        .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.05), radius: isSelected ? 18 : 12, x: 0, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture { onSelect() }
        .onTapGesture(count: 2) { onOpen() }
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
                    .fixedSize(horizontal: true, vertical: false)
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
    let onLoadURLPreviewImage: (String) -> Data?

    private let cardWidth: CGFloat = 300
    private let cardHeight: CGFloat = 250

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                AppIconView(bundleID: item.sourceBundleID)
                    .frame(width: 22 * scale, height: 22 * scale)
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

            if displayColorHex != nil {
                EmptyView()
            } else if item.kind != .url {
                if item.kind == .image {
                    Text(item.previewText)
                        .font(.system(size: 12 * scale, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
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
                }
            } else if item.metadataTitle == nil && item.metadataFaviconName == nil {
                Text(item.previewText)
                    .font(.system(size: 15 * scale, weight: .regular))
                    .foregroundStyle(Color(NSColor.labelColor))
                    .lineLimit(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text(metaText)
                    .font(.system(size: 11 * scale))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 48, alignment: .leading)
                Spacer(minLength: 4)

                Button {
                    onTogglePin?()
                } label: {
                    Image(systemName: item.isPinned ? "pin.slash" : "pin")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(localizedString("pin"))

                Button {
                    onToggleLock?()
                } label: {
                    Image(systemName: item.isLocked ? "lock.open" : "lock")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(localizedString("lock"))

                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(localizedString("copy"))

                Button(action: onMakeNote) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(localizedString("convert_to_note"))

                Button {
                    onDelete?()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(localizedString("delete"))
            }
        }
        .padding(14)
        .frame(width: cardWidth, height: cardHeight)
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
        if let hex = displayColorHex {
            ColorPreview(hex: hex, scale: scale)
        } else {
            switch item.payload {
        case .imageData(let data):
            if let image = NSImage(data: data) {
                GeometryReader { geo in
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                }
                .frame(height: 128)
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
            VStack(alignment: .leading, spacing: 8) {
                if let previewName = item.metadataImageName,
                   let previewData = onLoadURLPreviewImage(previewName),
                   let previewImage = NSImage(data: previewData) {
                    GeometryReader { geo in
                        Image(nsImage: previewImage)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                    .frame(height: 92 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor).opacity(0.2), lineWidth: 1)
                    )
                }

                HStack(alignment: .top, spacing: 10) {
                    if let faviconName = item.metadataFaviconName,
                       let faviconData = onLoadFavicon(faviconName),
                       let image = NSImage(data: faviconData) {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24 * scale, height: 24 * scale)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(NSColor.controlBackgroundColor))
                            Image(systemName: "globe")
                                .font(.system(size: 13 * scale))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 24 * scale, height: 24 * scale)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.metadataTitle ?? url.host ?? localizedString("link"))
                            .font(.system(size: 13 * scale, weight: .semibold))
                            .foregroundColor(Color(NSColor.labelColor))
                            .lineLimit(2)

                        if let description = item.metadataDescription, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 11 * scale))
                                .foregroundColor(.secondary)
                                .lineLimit(item.metadataImageName == nil ? 4 : 2)
                        }

                        Text(url.host ?? url.absoluteString)
                            .font(.system(size: 10 * scale))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(10 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.1), lineWidth: 1)
            )
        case .colorHex(let hex):
            ColorPreview(hex: hex, scale: scale)
        default:
            EmptyView()
            }
        }
    }

    private var iconName: String {
        switch item.kind {
        case .text: return "text.quote"
        case .url: return "link"
        case .image: return "photo"
        case .fileURLs: return "doc"
        case .color: return "paintpalette"
        }
    }

    private var metaText: String {
        if displayColorHex != nil {
            return localizedString("color")
        }

        switch item.payload {
        case .text(let t):
            return "\(t.count) \(localizedString("characters"))"
        case .url:
            return localizedString("link")
        case .imageData:
            return "IMG"
        case .fileURLs(let urls):
            return "\(urls.count) \(localizedString("files"))"
        case .colorHex:
            return localizedString("color")
        }
    }

    private var displayColorHex: String? {
        if case .colorHex(let hex) = item.payload {
            return ColorInfo.normalizedHex(hex)
        }
        return ColorInfo.normalizedHex(item.previewText)
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct ColorPreview: View {
    let hex: String
    let scale: CGFloat

    private var info: ColorInfo? {
        ColorInfo(hex: hex)
    }

    var body: some View {
        if let info {
            VStack(alignment: .leading, spacing: 7) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(info.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.10), lineWidth: 1)
                    )
                    .frame(height: 108)

                VStack(alignment: .leading, spacing: 3) {
                    colorLine("Hex", info.hex)
                    colorLine("RGB", "\(info.r), \(info.g), \(info.b)")
                    colorLine("HSL", "\(info.hslH), \(info.hslS), \(info.hslL)")
                    colorLine("OKLCH", info.oklch)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(hex)
                .font(.system(size: 14 * scale, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func colorLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10 * scale, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
            Text(value)
                .font(.system(size: 11 * scale, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(NSColor.labelColor))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

private struct ColorInfo {
    let hex: String
    let r: Int
    let g: Int
    let b: Int
    let color: Color
    let hslH: Int
    let hslS: Int
    let hslL: Int
    let oklch: String

    init?(hex: String) {
        guard let normalized = Self.normalizedHex(hex) else { return nil }
        let raw = String(normalized.dropFirst())
        guard raw.count == 6 || raw.count == 8,
              let value = UInt64(raw.prefix(6), radix: 16)
        else { return nil }

        let r = Int((value >> 16) & 0xff)
        let g = Int((value >> 8) & 0xff)
        let b = Int(value & 0xff)

        self.hex = "#\(raw.uppercased())"
        self.r = r
        self.g = g
        self.b = b
        self.color = Color(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0
        )

        let hsl = Self.hsl(r: r, g: g, b: b)
        self.hslH = hsl.h
        self.hslS = hsl.s
        self.hslL = hsl.l
        self.oklch = Self.oklch(r: r, g: g, b: b)
    }

    static func normalizedHex(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return nil }
        let raw = String(trimmed.dropFirst())
        switch raw.count {
        case 3:
            guard raw.allSatisfy(\.isHexDigit) else { return nil }
            let expanded = raw.map { "\($0)\($0)" }.joined()
            return "#\(expanded.uppercased())"
        case 6, 8:
            guard raw.allSatisfy(\.isHexDigit) else { return nil }
            return "#\(raw.uppercased())"
        default:
            return nil
        }
    }

    private static func hsl(r: Int, g: Int, b: Int) -> (h: Int, s: Int, l: Int) {
        let rf = Double(r) / 255.0
        let gf = Double(g) / 255.0
        let bf = Double(b) / 255.0
        let maxV = max(rf, gf, bf)
        let minV = min(rf, gf, bf)
        let l = (maxV + minV) / 2.0
        let d = maxV - minV
        guard d > 0 else { return (0, 0, Int((l * 100).rounded())) }

        let s = d / (1.0 - abs(2.0 * l - 1.0))
        let h: Double
        if maxV == rf {
            h = 60.0 * (((gf - bf) / d).truncatingRemainder(dividingBy: 6.0))
        } else if maxV == gf {
            h = 60.0 * (((bf - rf) / d) + 2.0)
        } else {
            h = 60.0 * (((rf - gf) / d) + 4.0)
        }

        let normalizedH = h < 0 ? h + 360.0 : h
        return (
            Int(normalizedH.rounded()),
            Int((s * 100).rounded()),
            Int((l * 100).rounded())
        )
    }

    private static func oklch(r: Int, g: Int, b: Int) -> String {
        func srgbToLinear(_ v: Double) -> Double {
            v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }

        let r = srgbToLinear(Double(r) / 255.0)
        let g = srgbToLinear(Double(g) / 255.0)
        let b = srgbToLinear(Double(b) / 255.0)

        let l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
        let m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
        let s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

        let l_ = cbrt(l)
        let m_ = cbrt(m)
        let s_ = cbrt(s)

        let L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
        let a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
        let b2 = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

        let c = sqrt(a * a + b2 * b2)
        var h = atan2(b2, a) * 180.0 / Double.pi
        if h < 0 { h += 360.0 }

        return String(format: "%.2f, %.2f, %.0f", L, c, h)
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

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
    let onToggleStandardWindow: () -> Void
    let onShowPreferences: () -> Void
    let onOpenFinder: () -> Void

    @State private var query: String = ""
    @State private var selectedSource: SourceFilter = .all
    @State private var selectedTag: String? = nil
    @State private var selectedID: UUID?
    @State private var noteTags: [UUID: [String]] = [:]
    private let deckScale: CGFloat = 0.82
    @State private var kind: ClipboardManager.Query.KindFilter = .all
    @State private var pinnedOnly: Bool = false
    @State private var recentOnly: Bool = false
    @State private var recentMinutes: Int = 60
    @State private var showExportPanel: Bool = false
    @State private var showClearConfirmation: Bool = false
    @State private var lightboxImage: NSImage?
    @State private var quickLookURLs: [URL] = []
    @State private var searchExpanded: Bool = false
    @State private var stripAnimated: Bool = false
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
        case trash
        case app(String)
    }

    var body: some View {
        ZStack {
            VibrancyBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                deck2WindowHeader
                deck2Toolbar
                deck2ScrollViewport
                deck2BottomStrip
            }
            .padding(.top, 12)
            .padding(.horizontal, 0)
            .padding(.bottom, 0)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(red: 223/255, green: 227/255, blue: 236/255).opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 34, x: 0, y: 20)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
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

    private var deck2WindowHeader: some View {
        ZStack(alignment: .top) {
            HStack {
                Color.clear
                    .frame(width: 52, height: 12)
                Spacer()
            }

            Capsule()
                .fill(Color(red: 60/255, green: 60/255, blue: 67/255).opacity(0.25))
                .frame(width: 38, height: 5)
                .offset(y: 2)
        }
        .padding(.horizontal, 24)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }

    private var deck2Toolbar: some View {
        HStack(spacing: 16) {
            deck2Search

            HStack(spacing: 4) {
                Deck2FilterPill(title: localizedString("filter_all"), dot: Color(red: 124/255, green: 130/255, blue: 141/255), isSelected: kind == .all) {
                    kind = .all
                    selectedSource = .all
                }
                Deck2FilterPill(title: localizedString("filter_text"), dot: Color(red: 59/255, green: 130/255, blue: 246/255), isSelected: kind == .text && selectedSource == .all) {
                    kind = .text
                    selectedSource = .all
                }
                Deck2FilterPill(title: localizedString("filter_image"), dot: Color(red: 16/255, green: 185/255, blue: 129/255), isSelected: kind == .image) {
                    kind = .image
                    selectedSource = .all
                }
                Deck2FilterPill(title: localizedString("filter_files"), dot: Color(red: 139/255, green: 92/255, blue: 246/255), isSelected: kind == .file) {
                    kind = .file
                    selectedSource = .all
                }
                Deck2FilterPill(title: localizedString("notes"), dot: Color(red: 239/255, green: 68/255, blue: 68/255), isSelected: selectedSource == .notes) {
                    kind = .text
                    selectedSource = .notes
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Deck2IconButton(systemName: "gearshape", help: localizedString("preferences"), action: onShowPreferences)
                Deck2IconButton(
                    systemName: clipboard.isPaused ? "play.fill" : "pause.fill",
                    help: clipboard.isPaused ? localizedString("resume") : localizedString("pause")
                ) {
                    clipboard.isPaused.toggle()
                }
                Deck2IconButton(systemName: "power", help: localizedString("quit_pkbrain")) {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.04))
                .frame(height: 1)
        }
    }

    private var deck2Search: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.35)) {
                    searchExpanded.toggle()
                }
                if searchExpanded {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        searchFocused = true
                    }
                } else {
                    searchFocused = false
                    query = ""
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 58/255, green: 63/255, blue: 71/255))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)

            if searchExpanded {
                TextField(localizedString("search"), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(red: 28/255, green: 28/255, blue: 30/255))
                    .focused($searchFocused)
                    .frame(width: 160, height: 32)
                    .padding(.leading, 6)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .frame(width: searchExpanded ? 200 : 28, height: 32, alignment: .leading)
        .background(Color.black.opacity(0.04))
        .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var deck2ScrollViewport: some View {
        let entries = filteredEntries
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        switch entry {
                        case .clipboard(let item):
                            DeckCard(
                                item: item,
                                shortcutIndex: index + 1,
                                isSelected: selectedID == item.id,
                                onSelect: { selectedID = item.id },
                                onCopy: { onCopyItem(item) },
                                onMakeNote: { onCreateNoteFromItem(item) },
                                scale: 1,
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
                                scale: 1,
                                onSelect: { selectedID = note.id },
                                onOpen: { onOpenNote(note.id) }
                            )
                            .id(note.id)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)
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

    private var deck2BottomStrip: some View {
        GeometryReader { geo in
            let pattern = "⠿⠟⠛⠻⠽⠾⠷⠯⠟⠿   "
            let line = String(repeating: pattern, count: 70)
            ZStack {
                Color.black.opacity(0.015)
                HStack(spacing: 0) {
                    Text(line)
                    Text(line)
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(red: 60/255, green: 64/255, blue: 73/255).opacity(0.25))
                .tracking(2.2)
                .offset(x: stripAnimated ? -(geo.size.width) : 0)
                .animation(.linear(duration: 50).repeatForever(autoreverses: false), value: stripAnimated)
            }
            .onAppear {
                stripAnimated = true
            }
        }
        .frame(height: 40)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.02))
                .frame(height: 1)
        }
        .clipped()
    }

    private var drawerHeader: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 10, height: 10)
                    Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 10, height: 10)
                    Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.25)).frame(width: 10, height: 10)
                }
                Spacer()
            }
            Capsule()
                .fill(Color.black.opacity(0.18))
                .frame(width: 40, height: 5)
        }
        .padding(.horizontal, 24)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var topRow: some View {
        let entries = filteredEntries
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        switch entry {
                        case .clipboard(let item):
                            DeckCard(
                                item: item,
                                shortcutIndex: index + 1,
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
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 320)
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
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
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
                .padding(.vertical, 0)
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 16) {
            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                        searchExpanded.toggle()
                    }
                    if searchExpanded {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            searchFocused = true
                        }
                    } else {
                        searchFocused = false
                        query = ""
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                if searchExpanded {
                    TextField(localizedString("search"), text: $query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 180)
                        .padding(.trailing, 10)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .frame(width: searchExpanded ? 200 : 28, height: 32, alignment: .leading)
            .background(Color.black.opacity(0.05))
            .clipShape(Capsule())

            Picker("", selection: $kind) {
                Text(localizedString("filter_all")).tag(ClipboardManager.Query.KindFilter.all)
                Text(localizedString("filter_text")).tag(ClipboardManager.Query.KindFilter.text)
                Text(localizedString("filter_url")).tag(ClipboardManager.Query.KindFilter.url)
                Text(localizedString("filter_image")).tag(ClipboardManager.Query.KindFilter.image)
                Text(localizedString("filter_files")).tag(ClipboardManager.Query.KindFilter.file)
                Text(localizedString("filter_color")).tag(ClipboardManager.Query.KindFilter.color)
            }
            .frame(width: 160)

            Spacer()

            Button(action: onShowPreferences) {
                Image(systemName: "gearshape")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(localizedString("preferences"))

            Button {
                clipboard.isPaused.toggle()
            } label: {
                Image(systemName: clipboard.isPaused ? "play.fill" : "pause.fill")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(clipboard.isPaused ? localizedString("resume") : localizedString("pause"))

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(localizedString("quit_pkbrain"))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(.clear)
                .overlay(
                    Rectangle()
                        .fill(Color.black.opacity(0.07))
                        .frame(height: 1),
                    alignment: .top
                )
        )
        .confirmationDialog(
            localizedString("clipboard_clear_confirm_title"),
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(localizedString("clipboard_clear_confirm_action"), role: .destructive) {
                clipboard.clear()
            }
            Button("Vider la poubelle", role: .destructive) {
                clipboard.clearTrash()
            }
            Button(localizedString("cancel"), role: .cancel) {}
        } message: {
            Text(localizedString("clipboard_clear_confirm_message"))
        }
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
            if let existing = byBundle[bid] {
                byBundle[bid] = SourceChipModel(bundleID: existing.bundleID, name: existing.name, icon: existing.icon, count: existing.count + 1)
            } else {
                byBundle[bid] = SourceChipModel(bundleID: bid, name: name, icon: appIcon(bundleID: bid), count: 1)
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
            withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.35)) {
                searchExpanded = true
            }
            searchFocused = true
            return true
        }

        if !searchFocused, let typed = searchText(from: event) {
            if !searchExpanded {
                withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.35)) {
                    searchExpanded = true
                }
            }
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

        // Cmd+C copies selected entry to system clipboard.
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "c"
        {
            guard let id = selectedID, let entry = entries.first(where: { $0.id == id }) else { return true }
            switch entry {
            case .clipboard(let item):
                onCopyItem(item)
            case .note(let note):
                let item = ClipboardManager.Item(
                    id: UUID(),
                    createdAt: Date(),
                    sourceBundleID: nil,
                    sourceAppName: nil,
                    kind: .text,
                    previewText: note.content,
                    payload: .text(note.content),
                    isPinned: false,
                    isLocked: false,
                    isTrashed: false,
                    tags: [],
                    metadataTitle: note.title.isEmpty ? nil : note.title,
                    metadataDescription: nil,
                    metadataFaviconName: nil,
                    metadataImageName: nil
                )
                onCopyItem(item)
            }
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
        case .trash:
            return "trash"
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
    @State private var hovering = false

    private let cardWidth: CGFloat = 216
    private let cardHeight: CGFloat = 304

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
        .padding(12)
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(note.theme.backgroundColor)
                        .padding(3)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? Color(red: 0/255, green: 122/255, blue: 255/255).opacity(0.65) : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity((hovering || isSelected) ? 0.13 : 0.05), radius: (hovering || isSelected) ? 20 : 12, x: 0, y: (hovering || isSelected) ? 12 : 8)
        .offset(y: hovering ? -4 : 0)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onHover { value in
            withAnimation(.easeOut(duration: 0.18)) {
                hovering = value
            }
        }
        .onTapGesture { onSelect() }
        .onTapGesture(count: 2) { onOpen() }
    }
}

private struct SourceChipModel {
    let bundleID: String
    let name: String
    let icon: NSImage?
    let count: Int
}

struct ClipboardStandardWindowView: View {
    @ObservedObject var clipboard: ClipboardManager
    let notesProvider: () -> [ClipboardView.NoteDeckItem]
    let onCreateNoteFromItem: (ClipboardManager.Item) -> Void
    let onOpenNote: (UUID) -> Void
    let onCopyItem: (ClipboardManager.Item) -> Void
    let onLoadFavicon: (String) -> Data?
    let onLoadURLPreviewImage: (String) -> Data?
    let onShowPreferences: () -> Void
    let onOpenFinder: () -> Void

    @State private var selectedSource: SourceFilter = .all
    @State private var selectedTag: String? = nil
    @State private var selectedID: UUID?
    @State private var noteTags: [UUID: [String]] = [:]
    @State private var query = ""
    @State private var isSidebarCollapsed = false
    @State private var keyMonitor: Any?
    @State private var currentPage: Int = 1
    @State private var itemsPerPage: Int = 50
    @FocusState private var searchFocused: Bool
    private let gridMinCardWidth: CGFloat = 190
    private let gridMaxCardWidth: CGFloat = 260
    private let gridSpacing: CGFloat = 10
    private let gridVerticalPadding: CGFloat = 24
    private let cardHeight: CGFloat = 170

    private enum SourceFilter: Equatable {
        case all
        case notes
        case trash
        case app(String)
    }

    enum GridEntry: Identifiable, Equatable {
        case clipboard(ClipboardManager.Item)
        case note(ClipboardView.NoteDeckItem)

        var id: UUID {
            switch self {
            case .clipboard(let item): return item.id
            case .note(let note): return note.id
            }
        }
    }

    var body: some View {
        ZStack {
            Color.white
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    sidebar
                        .frame(width: isSidebarCollapsed ? 56 : 220)
                    Divider()
                    mainGrid
                }
                Divider()
                footer
                    .frame(minHeight: 56)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.white)
        .frame(minWidth: 1120, minHeight: 720)
        .onAppear {
            selectedID = entries.first?.id
            installKeyMonitorIfNeeded()
        }
        .onDisappear { removeKeyMonitorIfNeeded() }
        .onChange(of: entries.map(\.id)) { ids in
            if let selectedID, ids.contains(selectedID) {
                clampCurrentPage()
                return
            }
            clampCurrentPage()
            selectedID = ids.first
        }
    }

    private var sidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isSidebarCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: isSidebarCollapsed ? "sidebar.right" : "sidebar.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, isSidebarCollapsed ? 14 : 16)
                .padding(.bottom, 6)

                sidebarButton(
                    title: localizedString("filter_all"),
                    systemImage: "house.fill",
                    isSelected: selectedSource == .all
                ) {
                    selectedSource = .all
                    selectedTag = nil
                    currentPage = 1
                }

                sidebarButton(
                    title: localizedString("notes"),
                    systemImage: "note.text",
                    isSelected: selectedSource == .notes
                ) {
                    selectedSource = .notes
                    selectedTag = nil
                    currentPage = 1
                }

                sidebarButton(
                    title: localizedString("trash"),
                    systemImage: "trash",
                    isSelected: selectedSource == .trash
                ) {
                    selectedSource = .trash
                    selectedTag = nil
                    currentPage = 1
                }

                if !isSidebarCollapsed {
                    sectionTitle("Tags")
                }
                ForEach(allTagItems, id: \.name) { tag in
                    tagRow(tag)
                }

                if !isSidebarCollapsed {
                    sectionTitle("Application")
                }
                ForEach(sourceChips, id: \.bundleID) { source in
                    Button {
                        selectedSource = .app(source.bundleID)
                        selectedTag = nil
                        currentPage = 1
                    } label: {
                        HStack(spacing: 8) {
                            if let icon = source.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                Image(systemName: "app")
                                    .frame(width: 16, height: 16)
                            }
                            if !isSidebarCollapsed {
                                Text(source.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Text("\(source.count)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.06))
                                    )
                                    .frame(width: 34, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, isSidebarCollapsed ? 12 : 16)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedSource == .app(source.bundleID) ? Color.black.opacity(0.10) : Color.clear)
                        )
                        .padding(.horizontal, isSidebarCollapsed ? 6 : 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.windowBackgroundColor).opacity(0.96))
    }

    private var mainGrid: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: gridMinCardWidth, maximum: gridMaxCardWidth), spacing: gridSpacing)],
                    spacing: gridSpacing
                ) {
                    ForEach(pagedEntries.indices, id: \.self) { index in
                        let entry = pagedEntries[index]
                        StandardClipboardCard(
                            entry: entry,
                            shortcutIndex: ((currentPage - 1) * itemsPerPage) + index + 1,
                            isSelected: selectedID == entry.id,
                            onSelect: { selectedID = entry.id },
                            onOpenNote: onOpenNote,
                            onCopyItem: onCopyItem,
                            onCreateNoteFromItem: onCreateNoteFromItem,
                        onLoadFavicon: onLoadFavicon,
                        onLoadURLPreviewImage: onLoadURLPreviewImage,
                        availableTags: allTags,
                        onAddTag: { id, tag in clipboard.addTag(tag, to: id) },
                        onRemoveTag: { id, tag in clipboard.removeTag(tag, from: id) },
                        onRestoreItem: { id in clipboard.restore(id) },
                        onDeletePermanently: { id in clipboard.deletePermanently(id) },
                        noteTags: noteTags,
                        onAddNoteTag: { id, tag in
                            let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !normalized.isEmpty else { return }
                            var tags = noteTags[id] ?? []
                            if !tags.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
                                tags.append(normalized)
                                tags.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                                noteTags[id] = tags
                            }
                        },
                        onRemoveNoteTag: { id, tag in
                            var tags = noteTags[id] ?? []
                            tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
                            noteTags[id] = tags
                        }
                    )
                }
            }
                .padding(12)
            }
            .background(Color.white)
            .onAppear {
                updateItemsPerPage(for: proxy.size)
            }
            .onChange(of: proxy.size) { size in
                updateItemsPerPage(for: size)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("Page")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            ForEach(1...min(14, max(1, totalPages)), id: \.self) { page in
                Button {
                    currentPage = page
                    if let first = pagedEntries.first {
                        selectedID = first.id
                    }
                } label: {
                    Text("\(page)")
                        .font(.system(size: 12, weight: page == currentPage ? .bold : .regular))
                        .foregroundStyle(page == currentPage ? Color.primary : Color.secondary)
                        .frame(minWidth: 16)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if selectedSource == .trash {
                Button {
                    clipboard.clearTrash()
                } label: {
                    Label("Vider la poubelle", systemImage: "trash.slash")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            Button(action: onOpenFinder) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(localizedString("open_notes_folder"))

            Button(action: onShowPreferences) {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(localizedString("preferences"))

            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color(NSColor.tertiaryLabelColor))
                TextField(localizedString("search"), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($searchFocused)
            }
            .padding(.horizontal, 10)
            .frame(width: 170, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color.white)
    }

    private func sidebarButton(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 16, height: 16)
                if !isSidebarCollapsed {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, isSidebarCollapsed ? 12 : 16)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.black.opacity(0.12) : Color.clear)
            )
            .padding(.horizontal, isSidebarCollapsed ? 6 : 8)
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }

    private func tagRow(_ tag: TagItem) -> some View {
        let isSelected = selectedTag == tag.name
        return Button {
            selectedTag = (selectedTag == tag.name) ? nil : tag.name
            currentPage = 1
        } label: {
        HStack(spacing: 8) {
            Circle()
                .fill(tagColor(for: tag.name))
                .frame(width: 10, height: 10)
            if !isSidebarCollapsed {
                Text(tag.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(tag.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.06))
                    )
                    .frame(width: 34, alignment: .trailing)
            }
        }
        .padding(.horizontal, isSidebarCollapsed ? 20 : 16)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.black.opacity(0.12) : Color.clear)
        )
        .padding(.horizontal, isSidebarCollapsed ? 6 : 8)
        }
        .buttonStyle(.plain)
    }

    private var allTags: [String] {
        allTagItems.map(\.name)
    }

    private struct TagItem {
        let name: String
        let count: Int
    }

    private var allTagItems: [TagItem] {
        var byTag: [String: Int] = [:]
        for item in clipboard.items {
            for tag in item.tags {
                byTag[tag, default: 0] += 1
            }
        }
        for tags in noteTags.values {
            for tag in tags {
                byTag[tag, default: 0] += 1
            }
        }
        return byTag.map { TagItem(name: $0.key, count: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func tagColor(for tag: String) -> Color {
        var hash: UInt64 = 1469598103934665603
        for b in tag.utf8 {
            hash ^= UInt64(b)
            hash &*= 1099511628211
        }
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.68, brightness: 0.9)
    }

    private var sourceChips: [SourceChipModel] {
        var byBundle: [String: SourceChipModel] = [:]
        for item in clipboard.items {
            guard let bundleID = item.sourceBundleID else { continue }
            let name = item.sourceAppName ?? localizedString("unknown_source")
            if let existing = byBundle[bundleID] {
                byBundle[bundleID] = SourceChipModel(bundleID: existing.bundleID, name: existing.name, icon: existing.icon, count: existing.count + 1)
            } else {
                byBundle[bundleID] = SourceChipModel(bundleID: bundleID, name: name, icon: appIcon(bundleID: bundleID), count: 1)
            }
        }
        return Array(byBundle.values).sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var entries: [GridEntry] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var output: [GridEntry] = []

        if selectedSource != .notes {
            let sourceBundleID: String?
            if case .app(let bundleID) = selectedSource {
                sourceBundleID = bundleID
            } else {
                sourceBundleID = nil
            }

            let query = ClipboardManager.Query(
                text: needle,
                sourceBundleID: sourceBundleID,
                includeTrashed: selectedSource == .trash
            )
            let clipboardItems = clipboard.filteredItems(query).filter { item in
                if selectedSource != .trash && item.isTrashed { return false }
                if selectedSource == .trash && !item.isTrashed { return false }
                guard let selectedTag else { return true }
                return item.tags.contains(where: { $0.caseInsensitiveCompare(selectedTag) == .orderedSame })
            }
            output.append(contentsOf: clipboardItems.map { ClipboardStandardWindowView.GridEntry.clipboard($0) })
        }

        if selectedSource == .all || selectedSource == .notes {
            let notes = notesProvider().filter { note in
                guard !needle.isEmpty else { return true }
                return "\(note.title)\n\(note.content)".lowercased().contains(needle)
            }.filter { note in
                guard let selectedTag else { return true }
                let tags = noteTags[note.id] ?? []
                return tags.contains(where: { $0.caseInsensitiveCompare(selectedTag) == .orderedSame })
            }
            output.append(contentsOf: notes.map { ClipboardStandardWindowView.GridEntry.note($0) })
        }

        return output
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
        guard let keyWindow = NSApp.keyWindow, keyWindow.title == "PKclipboard" else { return false }
        guard !entries.isEmpty else { return false }

        if selectedID == nil {
            selectedID = entries.first?.id
        }

        switch event.keyCode {
        case 3: // f
            if event.modifierFlags.contains(.command) {
                searchFocused = true
                return true
            }
            return false
        case 123: // left
            moveSelection(delta: -1)
            return true
        case 124: // right
            moveSelection(delta: +1)
            return true
        case 125: // down
            moveSelection(delta: +4)
            return true
        case 126: // up
            moveSelection(delta: -4)
            return true
        case 36, 76: // return / enter
            guard let id = selectedID, let entry = entries.first(where: { $0.id == id }) else { return true }
            performPrimaryAction(for: entry)
            return true
        case 8: // c
            if event.modifierFlags.contains(.command) {
                guard let id = selectedID, let entry = entries.first(where: { $0.id == id }) else { return true }
                switch entry {
                case .clipboard(let item):
                    onCopyItem(item)
                case .note(let note):
                    let item = ClipboardManager.Item(
                        id: UUID(),
                        createdAt: Date(),
                        sourceBundleID: nil,
                        sourceAppName: nil,
                        kind: .text,
                        previewText: note.content,
                        payload: .text(note.content),
                        isPinned: false,
                        isLocked: false,
                        isTrashed: false,
                        tags: [],
                        metadataTitle: note.title.isEmpty ? nil : note.title,
                        metadataDescription: nil,
                        metadataFaviconName: nil,
                        metadataImageName: nil
                    )
                    onCopyItem(item)
                }
                return true
            }
            return false
        case 53: // escape
            keyWindow.close()
            return true
        case 51: // backspace
            if !searchFocused, !query.isEmpty {
                query.removeLast()
                currentPage = 1
                return true
            }
            return false
        default:
            if !searchFocused, let typed = searchText(from: event) {
                query.append(typed)
                currentPage = 1
                return true
            }
            return false
        }
    }

    private func moveSelection(delta: Int) {
        guard let id = selectedID, let idx = entries.firstIndex(where: { $0.id == id }) else {
            selectedID = entries.first?.id
            return
        }
        let next = max(0, min(entries.count - 1, idx + delta))
        selectedID = entries[next].id
    }

    private func performPrimaryAction(for entry: GridEntry) {
        switch entry {
        case .clipboard(let item):
            onCopyItem(item)
        case .note(let note):
            onOpenNote(note.id)
        }
    }

    private var totalPages: Int {
        max(1, Int(ceil(Double(entries.count) / Double(itemsPerPage))))
    }

    private var pagedEntries: [GridEntry] {
        let start = max(0, (currentPage - 1) * itemsPerPage)
        let end = min(entries.count, start + itemsPerPage)
        guard start < end else { return [] }
        return Array(entries[start..<end])
    }

    private func clampCurrentPage() {
        currentPage = min(max(1, currentPage), totalPages)
    }

    private func updateItemsPerPage(for size: CGSize) {
        let columns = max(1, Int((size.width + gridSpacing) / (gridMinCardWidth + gridSpacing)))
        let availableHeight = max(1, size.height - gridVerticalPadding)
        let rows = max(1, Int((availableHeight + gridSpacing) / (cardHeight + gridSpacing)))
        let computed = max(1, columns * rows)
        if computed != itemsPerPage {
            itemsPerPage = computed
            clampCurrentPage()
        }
    }

    private func searchText(from event: NSEvent) -> String? {
        switch event.keyCode {
        case 123, 124, 125, 126, 36, 76, 48, 53:
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
}

private struct StandardClipboardCard: View {
    let entry: ClipboardStandardWindowView.GridEntry
    let shortcutIndex: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpenNote: (UUID) -> Void
    let onCopyItem: (ClipboardManager.Item) -> Void
    let onCreateNoteFromItem: (ClipboardManager.Item) -> Void
    let onLoadFavicon: (String) -> Data?
    let onLoadURLPreviewImage: (String) -> Data?
    let availableTags: [String]
    let onAddTag: (UUID, String) -> Void
    let onRemoveTag: (UUID, String) -> Void
    let onRestoreItem: (UUID) -> Void
    let onDeletePermanently: (UUID) -> Void
    let noteTags: [UUID: [String]]
    let onAddNoteTag: (UUID, String) -> Void
    let onRemoveNoteTag: (UUID, String) -> Void
    @State private var showExpandedPreview: Bool = false
    @State private var previewKeyMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            header
            bodyContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            footer
        }
        .frame(height: 170)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color(red: 0, green: 122/255, blue: 1) : cardBorderColor,
                    lineWidth: isSelected ? 3 : 1.5
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { onSelect() }
        .onTapGesture(count: 2) {
            switch entry {
            case .note(let note):
                onOpenNote(note.id)
            case .clipboard:
                showExpandedPreview = true
            }
        }
        .contextMenu {
            contextTagMenu
        }
        .popover(isPresented: $showExpandedPreview, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            expandedPreviewView
                .frame(minWidth: 820, minHeight: 560)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            entryIcon
                .frame(width: 18, height: 18)
            if shortcutIndex <= 9 {
                Text("⌘\(shortcutIndex)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(shortcutColor)
            }
            Spacer()
            Text(relativeTime)
                .font(.system(size: 11))
                .foregroundStyle(timeColor)
        }
        .padding(.top, 8)
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    private var entryIcon: some View {
        switch entry {
        case .clipboard(let item):
            AppIconView(bundleID: item.sourceBundleID)
        case .note(let note):
            Image(systemName: note.isPinned ? "note.text.badge.plus" : "note.text")
                .foregroundStyle(note.theme.autoTextColorColor)
                .padding(2)
                .background(note.theme.backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch entry {
        case .note(let note):
            VStack(alignment: .leading, spacing: 6) {
                Text(note.title.isEmpty ? localizedString("empty_note") : note.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(2)
                Text(note.content)
                    .font(.system(size: 12.5))
                    .lineLimit(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        case .clipboard(let item):
            clipboardBody(item)
        }
    }

    @ViewBuilder
    private func clipboardBody(_ item: ClipboardManager.Item) -> some View {
        if let hex = displayColorHex(for: item), let info = ColorInfo(hex: hex) {
            ZStack {
                info.color
                Text(info.hex)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch item.payload {
            case .imageData(let data):
                if let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .clipped()
                }
            case .url(let url):
                VStack(alignment: .leading, spacing: 5) {
                    if let previewName = item.metadataImageName,
                       let data = onLoadURLPreviewImage(previewName),
                       let image = NSImage(data: data) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, minHeight: 86, maxHeight: 86)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    Text(item.metadataTitle ?? url.host ?? localizedString("link"))
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(2)
                    Text(url.absoluteString)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(NSColor.tertiaryLabelColor))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            case .fileURLs(let urls):
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(urls.prefix(4), id: \.self) { url in
                        HStack(spacing: 8) {
                            FileIconView(url: url)
                                .frame(width: 16, height: 16)
                            Text(url.lastPathComponent)
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            default:
                Text(item.metadataTitle ?? item.previewText)
                    .font(.system(size: 12.5))
                    .lineSpacing(2)
                    .lineLimit(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: footerIcon)
                .font(.system(size: 12))
                .foregroundStyle(footerColor)
            Text(footerText)
                .font(.system(size: 11))
                .foregroundStyle(footerColor)
                .lineLimit(1)
            Spacer()
            if case .clipboard(let item) = entry {
                if let primary = item.tags.first {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(tagColor(for: primary))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1))
                        if item.tags.count > 1 {
                            Text("+\(item.tags.count - 1)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Menu {
                    let existing = item.tags
                    if item.isTrashed {
                        Button(localizedString("restore")) { onRestoreItem(item.id) }
                        Button(localizedString("delete"), role: .destructive) { onDeletePermanently(item.id) }
                        Divider()
                    }
                    if !availableTags.isEmpty {
                        ForEach(availableTags, id: \.self) { tag in
                            if existing.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                                Button("Retirer tag: \(tag)") { onRemoveTag(item.id, tag) }
                            } else {
                                Button("Taguer: \(tag)") { onAddTag(item.id, tag) }
                            }
                        }
                        Divider()
                    }
                    Button("Nouveau tag…") {
                        if let newTag = promptForTagName(), !newTag.isEmpty {
                            onAddTag(item.id, newTag)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(NSColor.tertiaryLabelColor).opacity(0.9))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            } else if case .note(let note) = entry {
                if let primary = (noteTags[note.id] ?? []).first {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(tagColor(for: primary))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1))
                    }
                }
                Menu {
                    let existing = noteTags[note.id] ?? []
                    if !availableTags.isEmpty {
                        ForEach(availableTags, id: \.self) { tag in
                            if existing.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                                Button("Retirer tag: \(tag)") { onRemoveNoteTag(note.id, tag) }
                            } else {
                                Button("Taguer: \(tag)") { onAddNoteTag(note.id, tag) }
                            }
                        }
                        Divider()
                    }
                    Button("Nouveau tag…") {
                        if let newTag = promptForTagName(), !newTag.isEmpty {
                            onAddNoteTag(note.id, newTag)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(NSColor.tertiaryLabelColor).opacity(0.9))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(height: 30)
        .background(footerBackground)
    }

    private var cardBackground: Color {
        switch entry {
        case .note(let note):
            return note.theme.backgroundColor
        case .clipboard:
            return Color.white
        }
    }

    private var cardBorderColor: Color {
        switch entry {
        case .note(let note):
            return note.theme.autoTextColorColor.opacity(0.24)
        case .clipboard:
            return Color.black.opacity(0.06)
        }
    }

    private var shortcutColor: Color {
        switch entry {
        case .note(let note):
            return note.theme.autoTextColorColor.opacity(0.95)
        case .clipboard:
            return Color(red: 0, green: 122/255, blue: 1)
        }
    }

    private var timeColor: Color {
        switch entry {
        case .note(let note):
            return note.theme.autoTextColorColor.opacity(0.72)
        case .clipboard:
            return Color(NSColor.tertiaryLabelColor)
        }
    }

    private var footerColor: Color {
        switch entry {
        case .note(let note):
            return note.theme.autoTextColorColor.opacity(0.82)
        case .clipboard:
            return Color(NSColor.tertiaryLabelColor)
        }
    }

    private var footerBackground: Color {
        switch entry {
        case .note(let note):
            return note.theme.autoTextColorColor.opacity(0.10)
        case .clipboard:
            return Color.black.opacity(0.035)
        }
    }

    private var footerIcon: String {
        switch entry {
        case .note:
            return "note.text"
        case .clipboard(let item):
            switch item.payload {
            case .text: return "doc.text"
            case .url: return "link"
            case .imageData: return "photo"
            case .fileURLs: return "doc"
            case .colorHex: return "paintpalette"
            }
        }
    }

    private var footerText: String {
        switch entry {
        case .note(let note):
            return "\(note.content.count) \(localizedString("characters"))"
        case .clipboard(let item):
            if item.isTrashed {
                return localizedString("trash")
            }
            switch item.payload {
            case .text(let text):
                return "\(text.count) \(localizedString("characters"))"
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
    }

    private var relativeTime: String {
        let date: Date
        switch entry {
        case .clipboard(let item):
            date = item.createdAt
        case .note(let note):
            date = note.updatedAt
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func displayColorHex(for item: ClipboardManager.Item) -> String? {
        if case .colorHex(let hex) = item.payload {
            return ColorInfo.normalizedHex(hex)
        }
        return ColorInfo.normalizedHex(item.previewText)
    }

    private func performPrimaryAction() {
        switch entry {
        case .clipboard(let item):
            onCopyItem(item)
        case .note(let note):
            onOpenNote(note.id)
        }
    }

    @ViewBuilder
    private var contextTagMenu: some View {
        if case .clipboard(let item) = entry {
            let existing = item.tags
            if !availableTags.isEmpty {
                ForEach(availableTags, id: \.self) { tag in
                    if existing.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                        Button("Retirer tag: \(tag)") { onRemoveTag(item.id, tag) }
                    } else {
                        Button("Taguer: \(tag)") { onAddTag(item.id, tag) }
                    }
                }
                Divider()
            }
            Button("Nouveau tag…") {
                if let newTag = promptForTagName(), !newTag.isEmpty {
                    onAddTag(item.id, newTag)
                }
            }
        }
    }

    @ViewBuilder
    private var expandedPreviewView: some View {
        VStack(spacing: 14) {
                ScrollView {
                    Group {
                        switch entry {
                        case .note(let note):
                            Text(note.content)
                        case .clipboard(let item):
                            switch item.payload {
                            case .text(let text):
                                Text(text)
                            case .url(let url):
                                Text(url.absoluteString)
                            case .colorHex(let hex):
                                Text(hex)
                                    .font(.system(size: 36, weight: .semibold, design: .monospaced))
                            case .fileURLs(let urls):
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(urls, id: \.self) { url in
                                        Text(url.path)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            case .imageData(let data):
                                if let image = NSImage(data: data) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFit()
                                }
                            }
                        }
                    }
                    .font(.system(size: 18))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .textSelection(.enabled)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 30)
                }

                HStack(spacing: 10) {
                    ForEach(metadataBadges, id: \.self) { badge in
                        Text(badge)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(Color.white.opacity(0.16))
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 10)
        }
        .padding(14)
        .frame(maxWidth: 920, maxHeight: 680)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .onAppear { installPreviewKeyMonitorIfNeeded() }
        .onDisappear { removePreviewKeyMonitorIfNeeded() }
    }

    private var metadataBadges: [String] {
        switch entry {
        case .note(let note):
            var badges = ["\(note.content.count) chars", relativeTime]
            if note.isPinned { badges.append("Pinned") }
            return badges
        case .clipboard(let item):
            var badges: [String] = []
            if let source = item.sourceAppName { badges.append(source) }
            badges.append(item.kind.rawValue.capitalized)
            badges.append("\(item.previewText.count) chars")
            if !item.tags.isEmpty { badges.append("Tags: \(item.tags.joined(separator: ", "))") }
            badges.append(relativeTime)
            return badges
        }
    }

    private func installPreviewKeyMonitorIfNeeded() {
        guard previewKeyMonitor == nil else { return }
        previewKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 {
                showExpandedPreview = false
                return nil
            }
            return event
        }
    }

    private func removePreviewKeyMonitorIfNeeded() {
        if let previewKeyMonitor {
            NSEvent.removeMonitor(previewKeyMonitor)
            self.previewKeyMonitor = nil
        }
    }

    private func promptForTagName() -> String? {
        let alert = NSAlert()
        alert.messageText = "Nouveau tag"
        alert.informativeText = "Nom du tag:"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Annuler")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        alert.accessoryView = input
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        return input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tagColor(for tag: String) -> Color {
        var hash: UInt64 = 1469598103934665603
        for b in tag.utf8 {
            hash ^= UInt64(b)
            hash &*= 1099511628211
        }
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.68, brightness: 0.9)
    }
}

private func appIcon(bundleID: String) -> NSImage? {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    return nil
}

private struct Deck2FilterPill: View {
    let title: String
    let dot: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isSelected ? Color(red: 176/255, green: 181/255, blue: 190/255) : dot)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color(red: 85/255, green: 89/255, blue: 100/255) : Color.clear)
            )
            .foregroundStyle(isSelected ? Color.white : Color(red: 74/255, green: 78/255, blue: 87/255))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.25), value: isSelected)
    }
}

private struct Deck2IconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(hovering ? Color(red: 28/255, green: 28/255, blue: 30/255) : Color(red: 85/255, green: 89/255, blue: 100/255))
                .frame(width: 30, height: 30)
                .background(hovering ? Color.black.opacity(0.05) : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { value in
            withAnimation(.easeOut(duration: 0.16)) {
                hovering = value
            }
        }
    }
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
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? Color(red: 0.33, green: 0.35, blue: 0.39) : Color.black.opacity(0.04))
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(isSelected ? 0.0 : 0.06), lineWidth: 1)
                    )
            )
            .foregroundStyle(isSelected ? Color.white : Color(red: 0.29, green: 0.31, blue: 0.35))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: isSelected)
    }
}

private struct DeckCard: View {
    let item: ClipboardManager.Item
    let shortcutIndex: Int
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
    @State private var hovering = false

    private let cardWidth: CGFloat = 216
    private let cardHeight: CGFloat = 304

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                AppIconView(bundleID: item.sourceBundleID)
                    .frame(width: 26, height: 26)
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                if item.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if shortcutIndex <= 9 {
                    Text("⌘\(shortcutIndex)")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color(red: 0, green: 122/255, blue: 1))
                }
                Text(relativeTime(item.createdAt))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            preview

            if displayColorHex != nil {
                EmptyView()
            } else if item.kind != .url {
                if item.kind == .image {
                    Text(item.previewText)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(item.metadataTitle ?? item.previewText)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(Color(NSColor.labelColor))
                        .lineLimit(7)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if item.metadataTitle != nil {
                        Text(item.previewText)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else if item.metadataTitle == nil && item.metadataFaviconName == nil {
                Text(item.previewText)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Color(NSColor.labelColor))
                    .lineLimit(7)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text(metaText)
                    .font(.system(size: 10.5, weight: .semibold))
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
        .padding(12)
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(Color.white.opacity(0.98))
                        .padding(3)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? Color(red: 0/255, green: 122/255, blue: 255/255).opacity(0.65) : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity((hovering || isSelected) ? 0.13 : 0.04), radius: (hovering || isSelected) ? 20 : 14, x: 0, y: (hovering || isSelected) ? 12 : 8)
        .offset(y: hovering ? -4 : 0)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onHover { value in
            withAnimation(.easeOut(duration: 0.18)) {
                hovering = value
            }
        }
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

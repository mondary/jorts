import SwiftUI

final class CommandPaletteState: ObservableObject {
    @Published var query: String = ""
    @Published var selection: CommandPaletteItem.ID?

    init(query: String = "", selection: CommandPaletteItem.ID? = nil) {
        self.query = query
        self.selection = selection
    }
}

enum CommandPaletteItem: Identifiable {
    case note(NoteDocument)
    case action(PaletteAction)

    var id: String {
        switch self {
        case .note(let doc): return "note-\(doc.id.uuidString)"
        case .action(let action): return "action-\(action.rawValue)"
        }
    }

    enum PaletteAction: String, CaseIterable {
        case newNote = "new_note"
        case settings = "settings"
        case about = "about"

        var title: String {
            switch self {
            case .newNote: return localizedString("create_new_note")
            case .settings: return localizedString("preferences")
            case .about: return localizedString("about_jorts")
            }
        }

        var icon: String {
            switch self {
            case .newNote: return "plus.circle.fill"
            case .settings: return "gearshape.fill"
            case .about: return "info.circle.fill"
            }
        }
    }
}

struct CommandPaletteView: View {
    let documents: [NoteDocument]
    let onOpenNote: (UUID) -> Void
    let onCreateNote: () -> Void
    let onShowPreferences: () -> Void
    let onShowAbout: () -> Void
    let onClose: () -> Void
    let state: CommandPaletteState

    @FocusState private var searchFocused: Bool
    @State private var hoverID: CommandPaletteItem.ID?

    var body: some View {
        ZStack {
            // Outer Bezel / Glass
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 15)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 0) {
                header
                    .padding(.top, 4)

                if results.isEmpty {
                    emptyState
                } else {
                    resultsList
                }

                footer
            }
        }
        .padding(20)
        .frame(width: 640, height: 480)
        .onAppear {
            searchFocused = true
            if state.selection == nil {
                state.selection = results.first?.id
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField(
                    localizedString("search_notes_or_commands"),
                    text: Binding(
                        get: { state.query },
                        set: { state.query = $0 }
                    )
                )
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .regular, design: .default))
                    .focused($searchFocused)
                    .onSubmit { handleSelection() }

                if !state.query.isEmpty {
                    Button {
                        state.query = ""
                        searchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }

                HStack(spacing: 4) {
                    Text("ESC")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                }
                .foregroundStyle(.secondary)
                .opacity(0.6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)

            Divider()
                .opacity(0.1)
        }
        .onExitCommand { onClose() }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(results) { item in
                        row(for: item)
                            .id(item.id)
                    }
                }
                .padding(10)
            }
            .scrollIndicators(.never)
            .onChange(of: state.selection) { newValue in
                guard let selected = newValue else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    proxy.scrollTo(selected, anchor: .center)
                }
            }
            .onChange(of: state.query) { _ in
                state.selection = results.first?.id
            }
        }
    }

    private func row(for item: CommandPaletteItem) -> some View {
        let isSelected = state.selection == item.id
        let isHovered = hoverID == item.id

        return HStack(spacing: 12) {
            icon(for: item)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: item))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.9))

                if let sub = subtitle(for: item) {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .opacity(0.8)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                }
            }
        }
        .contentShape(Rectangle())
        .onHover { over in
            withAnimation(.easeInOut(duration: 0.2)) {
                hoverID = over ? item.id : nil
            }
        }
        .onTapGesture {
            state.selection = item.id
            handleSelection()
        }
    }

    @Namespace private var selectionNamespace

    @ViewBuilder
    private func icon(for item: CommandPaletteItem) -> some View {
        switch item {
        case .note(let doc):
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(doc.theme.backgroundColor)
                    .shadow(color: doc.theme.backgroundColor.opacity(0.3), radius: 4, x: 0, y: 2)

                Image(systemName: "note.text")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(doc.theme.autoTextColorColor)
            }
        case .action(let action):
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))

                Image(systemName: action.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func title(for item: CommandPaletteItem) -> String {
        switch item {
        case .note(let doc): return doc.title.isEmpty ? localizedString("untitled_note") : doc.title
        case .action(let action): return action.title
        }
    }

    private func subtitle(for item: CommandPaletteItem) -> String? {
        switch item {
        case .note(let doc):
            let content = doc.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return content.isEmpty ? nil : content
        case .action: return localizedString("system_command")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(localizedString("no_results_for", state.query))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            Text(localizedString("try_searching_note"))
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.1)

            HStack {
                Text(localizedString("results_count", results.count))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                Spacer()

                HStack(spacing: 12) {
                    footerHint(key: "↑↓", label: localizedString("navigate"))
                    footerHint(key: "↵", label: localizedString("open"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func footerHint(key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 4)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
        .opacity(0.8)
    }

    private var results: [CommandPaletteItem] {
        let q = state.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var items: [CommandPaletteItem] = []

        // Actions first if query matches
        for action in CommandPaletteItem.PaletteAction.allCases {
            if q.isEmpty || action.title.lowercased().contains(q) {
                items.append(.action(action))
            }
        }

        // Notes
        let noteItems = documents
            .filter { doc in
                if q.isEmpty { return true }
                return doc.title.lowercased().contains(q) || doc.content.lowercased().contains(q)
            }
            .sorted { lhs, rhs in
                score(for: lhs, query: q) > score(for: rhs, query: q)
            }
            .map { CommandPaletteItem.note($0) }

        items.append(contentsOf: noteItems)
        return items
    }

    private func score(for doc: NoteDocument, query: String) -> Int {
        if query.isEmpty { return 0 }
        let title = doc.title.lowercased()
        let content = doc.content.lowercased()

        if title.hasPrefix(query) { return 100 }
        if title.contains(query) { return 80 }
        if content.contains(query) { return 40 }
        return 0
    }

    private func handleSelection() {
        guard let selection = state.selection,
              let item = results.first(where: { $0.id == selection }) else {
            return
        }

        switch item {
        case .note(let doc):
            onOpenNote(doc.id)
        case .action(let action):
            switch action {
            case .newNote: onCreateNote()
            case .settings: onShowPreferences()
            case .about: onShowAbout()
            }
            onClose()
        }
    }

    func moveSelection(delta: Int) {
        guard !results.isEmpty else { return }

        let ids = results.map(\.id)
        if let current = state.selection, let idx = ids.firstIndex(of: current) {
            let next = (idx + delta + ids.count) % ids.count
            state.selection = ids[next]
        } else {
            state.selection = ids.first
        }
    }
}

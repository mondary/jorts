import SwiftUI

final class CommandPaletteState: ObservableObject {
    @Published var query: String = ""
    @Published var selection: UUID?

    init(query: String = "", selection: UUID? = nil) {
        self.query = query
        self.selection = selection
    }
}

struct CommandPaletteView: View {
    let documents: [NoteDocument]
    let onOpenNote: (UUID) -> Void
    let onClose: () -> Void
    let state: CommandPaletteState

    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 0) {
                header

                Divider()
                    .overlay(Color.white.opacity(0.08))

                resultsList
            }
        }
        .padding(18)
        .frame(width: 720, height: 520)
        .onAppear {
            searchFocused = true
            if state.selection == nil {
                state.selection = results.first?.id
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                "Search notes…",
                text: Binding(
                    get: { state.query },
                    set: { state.query = $0 }
                )
            )
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { openSelectionOrFirst() }

            if !state.query.isEmpty {
                Button {
                    state.query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 15, weight: .medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(16)
        .onExitCommand { onClose() }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            List(
                selection: Binding(
                    get: { state.selection },
                    set: { state.selection = $0 }
                )
            ) {
                ForEach(results, id: \.id) { doc in
                    row(for: doc)
                        .tag(doc.id)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .onChange(of: state.selection) { newValue in
                guard let selected = newValue else { return }
                proxy.scrollTo(selected, anchor: .center)
            }
            .onChange(of: state.query) { _ in
                state.selection = results.first?.id
            }
            .onSubmit { openSelectionOrFirst() }
        }
    }

    private func row(for doc: NoteDocument) -> some View {
        let isSelected = state.selection == doc.id
        return HStack(spacing: 12) {
            Circle()
                .fill(doc.theme.backgroundColor)
                .frame(width: 10, height: 10)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(doc.title.isEmpty ? "Untitled" : doc.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)

                if !doc.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(previewText(for: doc))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if isSelected {
                Text("↩︎")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            state.selection = doc.id
        }
        .onTapGesture(count: 2) {
            onOpenNote(doc.id)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.10) : .clear)
        )
    }

    private var results: [NoteDocument] {
        let trimmed = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return documents
        }

        let q = trimmed.lowercased()
        return documents
            .filter { doc in
                let title = doc.title.lowercased()
                let content = doc.content.lowercased()
                return title.contains(q) || content.contains(q)
            }
            .sorted { lhs, rhs in
                score(for: lhs, query: q) > score(for: rhs, query: q)
            }
    }

    private func score(for doc: NoteDocument, query: String) -> Int {
        let title = doc.title.lowercased()
        let content = doc.content.lowercased()

        if title.hasPrefix(query) { return 100 }
        if title.contains(query) { return 80 }
        if content.contains(query) { return 40 }
        return 0
    }

    private func openSelectionOrFirst() {
        if let selection = state.selection {
            onOpenNote(selection)
            return
        }
        if let first = results.first {
            onOpenNote(first.id)
        }
    }

    func moveSelection(delta: Int) {
        guard !results.isEmpty else { return }

        let ids = results.map(\.id)
        if let current = state.selection, let idx = ids.firstIndex(of: current) {
            let next = (idx + delta).clamped(to: 0...(ids.count - 1))
            state.selection = ids[next]
        } else {
            state.selection = ids.first
        }
    }

    private func previewText(for doc: NoteDocument) -> String {
        let trimmed = doc.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 120 { return trimmed }
        return String(trimmed.prefix(120)) + "…"
    }
}

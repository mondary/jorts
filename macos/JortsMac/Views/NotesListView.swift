import SwiftUI

struct NotesListView: View {
    let documents: [NoteDocument]
    let trash: [TrashedNote]
    let onCreateNote: () -> Void
    let onShowPreferences: () -> Void
    let onOpenFinder: () -> Void
    let onNoteSelected: (UUID) -> Void
    let onOpenTrashed: (UUID) -> Void

    @State private var selection: ListSelection = .notes

    var body: some View {
        VStack(spacing: 0) {
            header

            if selection == .notes && documents.isEmpty {
                emptyState
            } else if selection == .trash && trash.isEmpty {
                trashEmptyState
            } else {
                list
            }
        }
        .frame(minWidth: 400, minHeight: 420)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Text(selection == .trash ? "Poubelle" : "Toutes mes notes")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button(action: onCreateNote) {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("New note")

                Button(action: onShowPreferences) {
                    Image(systemName: "gearshape")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Preferences")

                Button(action: onOpenFinder) {
                    Image(systemName: "folder")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Open notes folder in Finder")

                Button {
                    selection = (selection == .trash) ? .notes : .trash
                } label: {
                    Image(systemName: selection == .trash ? "arrow.uturn.backward.circle.fill" : "arrow.uturn.backward.circle")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Restore / Trash")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(NSLocalizedString("no_notes", bundle: .main, comment: ""))
                .font(.title3)
                .foregroundColor(.secondary)

            Text("Create your first note to get started")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var trashEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Poubelle vide")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                switch selection {
                case .notes:
                    ForEach(documents) { document in
                        NoteRow(document: document)
                            .onTapGesture {
                                onNoteSelected(document.id)
                            }
                        Divider()
                    }
                case .trash:
                    ForEach(trash) { item in
                        TrashedNoteRow(item: item)
                            .onTapGesture { onOpenTrashed(item.id) }
                        Divider()
                    }
                }
            }
        }
    }
}

private enum ListSelection: Hashable {
    case notes
    case trash
}

struct NoteRow: View {
    @ObservedObject var document: NoteDocument

    var body: some View {
        HStack(spacing: 12) {
            swatch.frame(width: 4).cornerRadius(2)

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title.isEmpty ? "Untitled" : document.title)
                    .font(.headline)
                    .foregroundColor(document.theme.foregroundColor)

                Text(document.content.isEmpty ? "No content" : String(document.content.prefix(100)))
                    .font(.body)
                    .foregroundColor(document.theme.foregroundColor.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer()

            Text(lastEdited)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(document.theme.backgroundColor.opacity(0.3))
        .contentShape(Rectangle())
    }

    private var swatch: Color {
        document.theme.backgroundColor
    }

    private var lastEdited: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: Date(), relativeTo: Date())
    }
}

struct TrashedNoteRow: View {
    let item: TrashedNote

    var body: some View {
        HStack(spacing: 12) {
            item.note.theme.backgroundColor.frame(width: 4).cornerRadius(2)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.note.title.isEmpty ? "Untitled" : item.note.title)
                    .font(.headline)
                    .foregroundColor(item.note.theme.foregroundColor)

                Text(item.note.content.isEmpty ? "No content" : String(item.note.content.prefix(100)))
                    .font(.body)
                    .foregroundColor(item.note.theme.foregroundColor.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer()

            Text(deletedAt)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(item.note.theme.backgroundColor.opacity(0.15))
        .contentShape(Rectangle())
    }

    private var deletedAt: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: item.deletedAt, relativeTo: Date())
    }
}

import SwiftUI

struct NotesListView: View {
    let documents: [NoteDocument]
    let onCreateNote: () -> Void
    let onClose: () -> Void
    let onNoteSelected: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            if documents.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            Text("All Notes")
                .font(.title2.weight(.semibold))

            Spacer()

            Button(action: onCreateNote) {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("New note")

            Button(action: onClose) {
                Image(systemName: "xmark.circle")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Close list")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No notes yet")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("Create your first note to get started")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(documents) { document in
                    NoteRow(document: document)
                        .onTapGesture {
                            onNoteSelected(document.id)
                        }
                    Divider()
                }
            }
        }
    }
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

import SwiftUI

struct ClipboardView: View {
    @ObservedObject var clipboard: ClipboardManager
    let onCreateNoteFromItem: (ClipboardManager.Item) -> Void
    let onCopyItem: (ClipboardManager.Item) -> Void

    @State private var query: String = ""
    @State private var selectedSource: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(minWidth: 720, minHeight: 320)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text(localizedString("clipboard"))
                    .font(.title2.weight(.semibold))

                Spacer()

                Toggle(isOn: Binding(
                    get: { !clipboard.isPaused },
                    set: { clipboard.isPaused = !$0 }
                )) {
                    Text(localizedString("clipboard_capture"))
                        .font(.subheadline)
                }
                .toggleStyle(.switch)

                Button {
                    clipboard.clear()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(localizedString("clear"))
            }

            HStack(spacing: 10) {
                TextField(localizedString("search"), text: $query)
                    .textFieldStyle(.roundedBorder)

                Picker("", selection: $selectedSource) {
                    Text(localizedString("all_sources")).tag(String?.none)
                    ForEach(sources, id: \.self) { src in
                        Text(src).tag(String?.some(src))
                    }
                }
                .frame(width: 220)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var content: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(filteredItems) { item in
                    ClipboardCard(
                        item: item,
                        onCopy: { onCopyItem(item) },
                        onMakeNote: { onCreateNoteFromItem(item) }
                    )
                }
            }
            .padding(12)
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 10, alignment: .top)
        ]
    }

    private var sources: [String] {
        Array(Set(clipboard.items.compactMap { $0.sourceAppName })).sorted()
    }

    private var filteredItems: [ClipboardManager.Item] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return clipboard.items.filter { item in
            if let selectedSource, item.sourceAppName != selectedSource { return false }
            if q.isEmpty { return true }
            return item.previewText.lowercased().contains(q) || (item.sourceAppName?.lowercased().contains(q) ?? false)
        }
    }
}

private struct ClipboardCard: View {
    let item: ClipboardManager.Item
    let onCopy: () -> Void
    let onMakeNote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .foregroundColor(.secondary)
                Text(item.sourceAppName ?? localizedString("unknown_source"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(relativeTime(item.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(item.previewText)
                .font(.system(.body, design: .default))
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(localizedString("copy"))

                Button(action: onMakeNote) {
                    Image(systemName: "note.text.badge.plus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help(localizedString("convert_to_note"))

                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch item.kind {
        case .text: return "text.quote"
        case .url: return "link"
        case .image: return "photo"
        case .fileURLs: return "doc"
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

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
                AppIconView(bundleID: item.sourceBundleID)
                    .frame(width: 18, height: 18)

                Image(systemName: iconName)
                    .font(.system(size: 12))
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

            preview

            Text(item.previewText)
                .font(.system(.body, design: .default))
                .lineLimit(item.kind == .image ? 2 : 5)
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

    @ViewBuilder
    private var preview: some View {
        switch item.payload {
        case .imageData(let data):
            if let image = NSImage(data: data) {
                GeometryReader { geo in
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .frame(height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 1)
                )
            }
        case .fileURLs(let urls):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(urls.prefix(3), id: \.self) { url in
                    HStack(spacing: 8) {
                        FileIconView(url: url)
                            .frame(width: 18, height: 18)
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                if urls.count > 3 {
                    Text("+ \(urls.count - 3)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
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

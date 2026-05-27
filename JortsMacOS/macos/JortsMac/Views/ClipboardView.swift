import SwiftUI

struct ClipboardView: View {
    @ObservedObject var clipboard: ClipboardManager
    let onCreateNoteFromItem: (ClipboardManager.Item) -> Void
    let onCopyItem: (ClipboardManager.Item) -> Void

    @State private var query: String = ""
    @State private var selectedSource: String? = nil
    @State private var selectedID: UUID?

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
        .frame(minWidth: 900, minHeight: 320)
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
                        onMakeNote: { onCreateNoteFromItem(item) }
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if selectedID == nil {
                selectedID = filteredItems.first?.id
            }
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

            Picker("", selection: $selectedSource) {
                Text(localizedString("all_sources")).tag(String?.none)
                ForEach(sources, id: \.self) { src in
                    Text(src).tag(String?.some(src))
                }
            }
            .frame(width: 220)

            Spacer()

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

    private var filteredItems: [ClipboardManager.Item] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return clipboard.items.filter { item in
            if let selectedSource, item.sourceAppName != selectedSource { return false }
            if q.isEmpty { return true }
            return item.previewText.lowercased().contains(q) || (item.sourceAppName?.lowercased().contains(q) ?? false)
        }
    }
}

private struct DeckCard: View {
    let item: ClipboardManager.Item
    let isSelected: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onMakeNote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                AppIconView(bundleID: item.sourceBundleID)
                    .frame(width: 22, height: 22)
                Text("⌘1")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0/255, green: 122/255, blue: 255/255))
                Spacer()
                Text(relativeTime(item.createdAt))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            preview

            Text(item.previewText)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(NSColor.labelColor))
                .lineLimit(10)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Text(metaText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .help(localizedString("copy"))

                Button(action: onMakeNote) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .help(localizedString("convert_to_note"))
            }
        }
        .padding(18)
        .frame(width: 320, height: 370)
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

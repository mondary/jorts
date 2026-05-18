import SwiftUI

struct NoteView: View {
    @ObservedObject var document: NoteDocument
    @ObservedObject var settings: AppSettings
    @State private var isPreferencesPopoverPresented = false
    @State private var fontSearchText = ""

    let onNew: () -> Void
    let onDelete: () -> Void
    let onSave: () -> Void
    let onShowEmoji: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            NoteTextView(
                text: $document.content,
                font: editorFont,
                textColor: document.theme.autoTextColor,
                insertionPointColor: document.theme.accentNSColor,
                listPrefix: settings.listItemPrefix,
                toggleListRequestToken: document.listToggleRequestToken
            )
            .background(document.theme.backgroundColor)

            if !settings.hideActionBar {
                Divider()
                    .overlay(document.theme.autoTextColorColor.opacity(0.18))
                actionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 240, minHeight: 240)
        .background(document.theme.backgroundColor)
        .foregroundStyle(document.theme.autoTextColorColor)
    }

    private var titleBar: some View {
        HStack(spacing: 10) {
            Spacer()
                .frame(width: 68)

            TextField("Title", text: $document.title)
                .textFieldStyle(.plain)
                .font(Font(titleFont))
                .foregroundStyle(document.theme.autoTextColorColor)
                .lineLimit(1)

            Button(action: onSave) {
                Image(systemName: "checkmark.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(document.theme.autoTextColorColor.opacity(0.72))
            .help("Save all notes")
        }
        .padding(.top, 13)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            iconButton("plus", help: "New sticky note", action: onNew)
            iconButton("trash", role: .destructive, help: "Delete sticky note", action: onDelete)

            Spacer()

            if !settings.listItemPrefix.isEmpty {
                iconButton("list.bullet", help: "Toggle list", action: document.toggleList)
            }

            iconButton("face.smiling", help: "Insert emoji", action: onShowEmoji)

            // Dedicated color button with brush icon
            Button {
                showColorPopover(for: document)
            } label: {
                Image(systemName: "paintbrush")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(document.theme.autoTextColorColor.opacity(0.78))
            .help("Change color")

            Button {
                isPreferencesPopoverPresented.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .renderingMode(.template)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(document.theme.autoTextColorColor.opacity(0.78))
            .popover(isPresented: $isPreferencesPopoverPresented, arrowEdge: .bottom) {
                notePreferencesPopover
            }
            .help("Preferences for this sticky note")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(document.theme.backgroundColor.opacity(0.98))
    }

    private var notePreferencesPopover: some View {
        NavigationStack {
            List {
                Section("Font") {
                    ForEach(filteredStandardFonts, id: \.self) { font in
                        Button {
                            document.fontFamily = font
                        } label: {
                            HStack {
                                Text(font.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if document.fontFamily == font {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if !filteredNerdFonts.isEmpty {
                        Divider()
                        ForEach(filteredNerdFonts, id: \.self) { font in
                            Button {
                                document.fontFamily = font
                            } label: {
                                HStack {
                                    Text(font.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if document.fontFamily == font {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Options") {
                    Toggle("Monospaced", isOn: $document.monospace)
                }

                Section("Zoom") {
                    HStack(spacing: 8) {
                        Button {
                            document.zoomOut()
                        } label: {
                            Image(systemName: "minus.magnifyingglass")
                        }
                        .help("Zoom Out")

                        Button {
                            document.resetZoom()
                        } label: {
                            Image(systemName: "1.magnifyingglass")
                        }
                        .help("Actual Size")

                        Button {
                            document.zoomIn()
                        } label: {
                            Image(systemName: "plus.magnifyingglass")
                        }
                        .help("Zoom In")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .navigationTitle("Preferences")
            .searchable(text: $fontSearchText, placement: .toolbar, prompt: "Search fonts")
            .modifier(SystemListBackgroundModifier())
        }
        // Prevent inheriting note colors; keep popover system-readable.
        .foregroundStyle(.primary)
        .tint(Color(NSColor.controlAccentColor))
        .background(Color(NSColor.windowBackgroundColor))
        .frame(width: 320, height: 420)
    }

    private struct SystemListBackgroundModifier: ViewModifier {
        func body(content: Content) -> some View {
            if #available(macOS 13.0, *) {
                content.scrollContentBackground(.hidden)
            } else {
                content
            }
        }
    }

    private var filteredStandardFonts: [FontFamily] {
        let fonts = FontFamily.standardFonts.filter { $0.isAvailable }
        return filterFonts(fonts)
    }

    private var filteredNerdFonts: [FontFamily] {
        filterFonts(FontFamily.nerdFonts)
    }

    private func filterFonts(_ fonts: [FontFamily]) -> [FontFamily] {
        let query = fontSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return fonts
        }

        return fonts.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    private var editorFont: NSFont {
        if settings.scribblyModeActive && !document.isFocused,
           let font = FontRegistrar.redactedFont(size: document.bodyFontSize) {
            return font
        }

        if let font = NSFont(name: document.fontFamily.fontName, size: document.bodyFontSize) {
            return font
        }

        if document.monospace {
            return .monospacedSystemFont(ofSize: document.bodyFontSize, weight: .regular)
        }

        return .systemFont(ofSize: document.bodyFontSize)
    }

    private var titleFont: NSFont {
        if let font = NSFont(name: document.fontFamily.fontName, size: document.titleFontSize) {
            return font
        }

        if document.monospace {
            return .monospacedSystemFont(ofSize: document.titleFontSize, weight: .semibold)
        }

        return .systemFont(ofSize: document.titleFontSize, weight: .semibold)
    }

    private func iconButton(
        _ systemName: String,
        role: ButtonRole? = nil,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .foregroundStyle(document.theme.autoTextColorColor.opacity(0.78))
        .help(help)
    }

    private func showColorPopover(for document: NoteDocument) {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 270, height: 360)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ColorGridView(document: document, popover: popover))

        if let window = NSApp.keyWindow,
           let contentView = window.contentView {
            let rect = NSRect(
                x: (contentView.bounds.width - 270) / 2,
                y: (contentView.bounds.height - 360) / 2,
                width: 270,
                height: 360
            )
            popover.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }
    }
}

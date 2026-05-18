import SwiftUI

struct NoteView: View {
    @ObservedObject var document: NoteDocument
    @ObservedObject var settings: AppSettings
    @State private var isPreferencesPopoverPresented = false
    @State private var isHistoryPopoverPresented = false
    @State private var fontSearchText = ""
    @State private var historyCursor = 0
    @State private var editorFocusRequestToken = 0

    let onNew: () -> Void
    let onDelete: () -> Void
    let onSave: () -> Void
    let onShowEmoji: () -> Void
    let onShowList: () -> Void
    let mode: NoteViewMode
    let onRestoreFromTrash: (() -> Void)?
    let onDeletePermanently: (() -> Void)?

    @FocusState private var focus: FocusTarget?

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            NoteTextView(
                text: $document.content,
                onShiftTabToTitle: { focus = .title },
                focusRequestToken: editorFocusRequestToken,
                isEditable: mode == .normal,
                typingEffect: settings.typingEffect,
                font: editorFont,
                textColor: document.theme.autoTextColor,
                insertionPointColor: document.theme.autoTextColor,
                listPrefix: settings.listItemPrefix,
                toggleListRequestToken: document.listToggleRequestToken
            )
            .background(document.theme.backgroundColor)

            if !settings.hideActionBar {
                Divider()
                    .overlay(document.theme.autoTextColorColor.opacity(0.18))
                Group {
                    switch mode {
                    case .normal:
                        actionBar
                    case .trash:
                        trashActionBar
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 240, minHeight: 240)
        .background(document.theme.backgroundColor)
        .foregroundStyle(document.theme.autoTextColorColor)
    }

    private var titleBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                Button(action: onSave) {
                    Image(systemName: "checkmark.circle")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(document.theme.autoTextColorColor.opacity(0.72))
                .help("Save all notes")
            }
            .frame(width: 44, alignment: .leading)

            TitleTextField(
                text: $document.title,
                font: titleFontBold,
                textColor: document.theme.autoTextColor,
                onTabToEditor: { editorFocusRequestToken += 1 }
            )
            .frame(maxWidth: 420)
            .focused($focus, equals: .title)

            // Keep symmetry so the title stays centered.
            Color.clear
                .frame(width: 44, height: 26)
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
            iconButton("note.text", help: "Show notes list", action: onShowList)

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

            Button {
                isHistoryPopoverPresented.toggle()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .renderingMode(.template)
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(document.theme.autoTextColorColor.opacity(0.78))
            .popover(isPresented: $isHistoryPopoverPresented, arrowEdge: .bottom) {
                noteHistoryPopover
            }
            .help("History (restore previous versions)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(document.theme.backgroundColor.opacity(0.98))
    }

    private var trashActionBar: some View {
        HStack(spacing: 10) {
            Spacer()

            Button {
                onRestoreFromTrash?()
            }
            label: {
                Label("Restaurer", systemImage: "arrow.uturn.backward")
            }
            .keyboardShortcut(.defaultAction)

            Button(role: .destructive) {
                onDeletePermanently?()
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(document.theme.backgroundColor.opacity(0.98))
    }

    private var notePreferencesPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Preferences")
                .font(.headline)
                .foregroundColor(Color(NSColor.labelColor))

            TextField("Search fonts", text: $fontSearchText)
                .textFieldStyle(.roundedBorder)
                .foregroundColor(Color(NSColor.labelColor))

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    fontSection("System", fonts: [], includesSystemMonospace: true)

                    Divider()
                        .padding(.vertical, 4)

                    fontSection("Standard Fonts", fonts: filteredStandardFonts)

                    if !filteredNerdFonts.isEmpty {
                        Divider()
                            .padding(.vertical, 4)
                        fontSection("Nerd Fonts", fonts: filteredNerdFonts)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 230)

            Divider()

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
        .padding(14)
        .foregroundColor(Color(NSColor.labelColor))
        .tint(Color(NSColor.controlAccentColor))
        .background(Color(NSColor.windowBackgroundColor).ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .frame(width: 320)
    }

    private var noteHistoryPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.headline)
                .foregroundColor(Color(NSColor.labelColor))

            if document.versions.isEmpty {
                Text("No versions yet.")
                    .font(.callout)
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                    .frame(maxWidth: .infinity, minHeight: 140, alignment: .center)
            } else {
                historyNavigator
            }
        }
        .padding(14)
        .foregroundColor(Color(NSColor.labelColor))
        .tint(Color(NSColor.controlAccentColor))
        .background(Color(NSColor.windowBackgroundColor).ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .frame(width: 360)
    }

    private var historyNavigator: some View {
        let versions = Array(document.versions.reversed())
        let clampedCursor = min(max(historyCursor, 0), max(0, versions.count - 1))
        let current = versions[clampedCursor]

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    historyCursor = max(0, clampedCursor - 1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(clampedCursor == 0)

                Button {
                    historyCursor = min(versions.count - 1, clampedCursor + 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(clampedCursor >= versions.count - 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(current.title.isEmpty ? "Untitled" : current.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(NSColor.labelColor))
                        .lineLimit(1)
                    Text("\(relativeDateString(current.date))  •  \(clampedCursor + 1)/\(versions.count)")
                        .font(.caption2.monospaced())
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                }

                Spacer()

                Button("Apply") {
                    restore(current)
                }
                .keyboardShortcut(.defaultAction)
            }
            .buttonStyle(.borderless)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if !current.content.isEmpty {
                        Text(current.content)
                            .font(.system(size: 12))
                            .foregroundColor(Color(NSColor.labelColor))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("(Empty note)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(NSColor.secondaryLabelColor))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .frame(height: 220)
        }
        .onAppear {
            historyCursor = 0
        }
    }

    private func restore(_ version: NoteVersion) {
        document.title = version.title
        document.content = version.content
        document.theme = version.theme
        document.monospace = version.monospace
        document.fontFamily = version.fontFamily
        document.zoom = version.zoom
    }

    private func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func fontSection(_ title: String, fonts: [FontFamily], includesSystemMonospace: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(Color(NSColor.secondaryLabelColor))
                .padding(.horizontal, 6)

            if includesSystemMonospace {
                Button {
                    document.monospace = true
                } label: {
                    HStack(spacing: 8) {
                        Text("System Monospace")
                            .font(.system(size: 13))
                            .foregroundColor(Color(NSColor.labelColor))
                            .lineLimit(1)

                        Spacer()

                        if document.monospace {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(NSColor.controlAccentColor))
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(document.monospace ? Color(NSColor.selectedContentBackgroundColor).opacity(0.18) : .clear)
                    )
                }
                .buttonStyle(.plain)
            }

            ForEach(fonts, id: \.self) { font in
                Button {
                    document.monospace = false
                    document.fontFamily = font
                } label: {
                    HStack(spacing: 8) {
                        Text(font.displayName)
                            .font(fontPreviewFont(for: font))
                            .foregroundColor(Color(NSColor.labelColor))
                            .lineLimit(1)

                        Spacer()

                        if document.fontFamily == font {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(NSColor.controlAccentColor))
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(document.fontFamily == font ? Color(NSColor.selectedContentBackgroundColor).opacity(0.18) : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func fontPreviewFont(for font: FontFamily) -> Font {
        // Render the font name in its own typeface, with a safe fallback.
        if NSFont(name: font.fontName, size: 13) != nil {
            return .custom(font.fontName, size: 13)
        }
        return .system(size: 13)
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

        if document.monospace {
            return .monospacedSystemFont(ofSize: document.bodyFontSize, weight: .regular)
        }

        if let font = NSFont(name: document.fontFamily.fontName, size: document.bodyFontSize) {
            return font
        }

        return .systemFont(ofSize: document.bodyFontSize)
    }

    private var titleFont: NSFont {
        if document.monospace {
            return .monospacedSystemFont(ofSize: document.titleFontSize, weight: .semibold)
        }

        if let font = NSFont(name: document.fontFamily.fontName, size: document.titleFontSize) {
            return font
        }

        return .systemFont(ofSize: document.titleFontSize, weight: .semibold)
    }

    private var titleFontBold: NSFont {
        if let converted = NSFontManager.shared.convert(titleFont, toHaveTrait: .boldFontMask) as NSFont? {
            return converted
        }
        return titleFont
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

private enum FocusTarget: Hashable {
    case title
    case editor
}

enum NoteViewMode: Hashable {
    case normal
    case trash
}

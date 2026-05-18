import SwiftUI

struct NoteView: View {
    @ObservedObject var document: NoteDocument
    @ObservedObject var settings: AppSettings

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
                textColor: document.theme.foregroundNSColor,
                insertionPointColor: document.theme.accentNSColor,
                listPrefix: settings.listItemPrefix,
                toggleListRequestToken: document.listToggleRequestToken
            )
            .background(document.theme.backgroundColor)

            if !settings.hideActionBar {
                Divider()
                    .overlay(document.theme.foregroundColor.opacity(0.18))
                actionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 240, minHeight: 240)
        .background(document.theme.backgroundColor)
        .foregroundStyle(document.theme.foregroundColor)
    }

    private var titleBar: some View {
        HStack(spacing: 10) {
            Spacer()
                .frame(width: 68)

            TextField("Title", text: $document.title)
                .textFieldStyle(.plain)
                .font(Font(titleFont))
                .foregroundStyle(document.theme.foregroundColor)
                .lineLimit(1)

            Button(action: onSave) {
                Image(systemName: "checkmark.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(document.theme.foregroundColor.opacity(0.72))
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

            Menu {
                themeMenu
                Divider()
                Toggle("Monospaced", isOn: $document.monospace)
                Divider()
                Button("Zoom In") { document.zoomIn() }
                Button("Zoom Out") { document.zoomOut() }
                Button("Actual Size") { document.resetZoom() }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: 26, height: 26)
            }
            .menuStyle(.borderlessButton)
            .help("Preferences for this sticky note")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(document.theme.backgroundColor.opacity(0.98))
    }

    @ViewBuilder private var themeMenu: some View {
        Section("Color") {
            ForEach(NoteTheme.allCases) { theme in
                Button {
                    document.theme = theme
                } label: {
                    HStack {
                        Circle()
                            .fill(theme.accentColor)
                            .frame(width: 10, height: 10)
                        Text(theme.displayName)
                        if document.theme == theme {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    private var editorFont: NSFont {
        if settings.scribblyModeActive && !document.isFocused,
           let font = FontRegistrar.redactedFont(size: document.bodyFontSize) {
            return font
        }

        if document.monospace {
            return .monospacedSystemFont(ofSize: document.bodyFontSize, weight: .regular)
        }

        return .systemFont(ofSize: document.bodyFontSize)
    }

    private var titleFont: NSFont {
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
        .foregroundStyle(document.theme.foregroundColor.opacity(0.78))
        .help(help)
    }
}

import SwiftUI
import AppKit

struct ColorGridView: View {
    @ObservedObject var document: NoteDocument
    let popover: NSPopover

    private let columns = Array(repeating: GridItem(.fixed(22), spacing: 2), count: 10)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Choose Color")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Color grid - all visible without scroll
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(NoteTheme.allCases) { theme in
                    ColorSwatch(
                        theme: theme,
                        isSelected: document.theme == theme,
                        action: {
                            document.theme = theme
                            closePopover()
                        }
                    )
                }
            }
            .padding(.horizontal, 8)

        }
        .frame(width: 270, height: 300)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func closePopover() {
        popover.performClose(nil)
    }
}

struct ColorSwatch: View {
    let theme: NoteTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 3)
                .fill(theme.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(theme.foregroundColor)
                        }
                    }
                )
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(theme.displayName)
    }
}

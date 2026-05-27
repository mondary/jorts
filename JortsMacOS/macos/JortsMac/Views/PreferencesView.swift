import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: AppSettings

    let storageURL: URL
    let onClose: () -> Void
    let onLanguageChanged: () -> Void

    @State private var selection: PreferencesSection = .general

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("JortsMacOS")
                    .font(.largeTitle.weight(.bold))
                    .padding(.bottom, 18)

                sidebarButton(.general, title: localizedString("general"), systemImage: "gearshape")
                sidebarButton(.shortcuts, title: localizedString("shortcuts"), systemImage: "keyboard")
                sidebarButton(.about, title: localizedString("about_section"), systemImage: "info.circle")

                Spacer()
            }
            .padding(18)
            .frame(width: 240)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                Text(selection.title)
                    .font(.title2.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                Group {
                    switch selection {
                    case .general:
                        GeneralPreferencesView(settings: settings, storageURL: storageURL, onRestartRequested: onLanguageChanged)
                    case .shortcuts:
                        ShortcutsPreferencesView(settings: settings)
                    case .about:
                        AboutPreferencesView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 920, height: 600)
        .onChange(of: settings.selectedLanguage) { _ in
            onLanguageChanged()
        }
    }

    private func sidebarButton(_ section: PreferencesSection, title: String, systemImage: String) -> some View {
        Button {
            selection = section
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .foregroundStyle(selection == section ? .white : .primary)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selection == section ? Color.accentColor : .clear)
                )
        }
        .buttonStyle(.plain)
    }
}

private enum PreferencesSection: Hashable {
    case general
    case shortcuts
    case about

    var title: String {
        switch self {
        case .general: localizedString("general")
        case .shortcuts: localizedString("shortcuts")
        case .about: localizedString("about_section")
        }
    }
}

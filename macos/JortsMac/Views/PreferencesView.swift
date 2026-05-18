import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: AppSettings

    let storageURL: URL
    let onClose: () -> Void
    let onLanguageChanged: () -> Void

    @State private var selection: PreferencesSection? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    Label(localizedString("general"), systemImage: "gearshape")
                        .tag(PreferencesSection.general)
                }

                Section {
                    Label("About", systemImage: "info.circle")
                        .tag(PreferencesSection.about)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            Group {
                switch selection ?? .general {
                case .general:
                    GeneralPreferencesView(settings: settings, storageURL: storageURL)
                        .navigationTitle(localizedString("general"))
                case .about:
                    AboutPreferencesView()
                        .navigationTitle("About")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("close"), action: onClose)
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .frame(width: 920, height: 600)
        .onAppear {
            if selection == nil {
                selection = .general
            }
        }
        .onChange(of: settings.selectedLanguage) { _ in
            onLanguageChanged()
        }
    }
}

private enum PreferencesSection: Hashable {
    case general
    case about
}

import SwiftUI

struct GeneralPreferencesView: View {
    @ObservedObject var settings: AppSettings
    let storageURL: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Language Section
            VStack(alignment: .leading, spacing: 8) {
                Text(localizedString("language"))
                    .font(.headline)

                Picker("", selection: $settings.selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            // Storage Section
            VStack(alignment: .leading, spacing: 8) {
                Text(localizedString("storage"))
                    .font(.headline)

                Text(storageURL.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

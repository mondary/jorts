import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: AppSettings

    let storageURL: URL
    let onClose: () -> Void
    let onLanguageChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localizedString("preferences_title"))
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizedString("list_item_prefix"))
                            .font(.headline)
                        Text(localizedString("list_item_prefix_hint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    TextField("", text: $settings.listItemPrefix)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 86)

                    Button(localizedString("reset")) {
                        settings.resetListPrefix()
                    }
                }

                HStack {
                    Text(localizedString("language"))
                        .font(.headline)

                    Spacer()

                    Picker("", selection: $settings.selectedLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .frame(width: 150)
                }

                Toggle(localizedString("scribble_mode"), isOn: $settings.scribblyModeActive)
                Toggle(localizedString("hide_action_bar"), isOn: $settings.hideActionBar)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(localizedString("storage"))
                    .font(.headline)
                Text(storageURL.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()

            HStack {
                Spacer()
                Button(localizedString("close"), action: onClose)
                    .keyboardShortcut(.defaultAction)
                    .frame(width: 96)
            }
        }
        .padding(20)
        .frame(width: 520, height: 360)
        .onChange(of: settings.selectedLanguage) { _ in
            onLanguageChanged()
        }
    }
}

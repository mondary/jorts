import SwiftUI

struct PreferencesView: View {
    @ObservedObject var settings: AppSettings

    let storageURL: URL
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Preferences for your Jorts")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("List item prefix")
                            .font(.headline)
                        Text("If left empty, the list button is hidden.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    TextField("", text: $settings.listItemPrefix)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 86)

                    Button("Reset") {
                        settings.resetListPrefix()
                    }
                }

                Toggle("Scribble text of unfocused notes", isOn: $settings.scribblyModeActive)
                Toggle("Hide bottom action bar", isOn: $settings.hideActionBar)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Storage")
                    .font(.headline)
                Text(storageURL.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Close", action: onClose)
                    .keyboardShortcut(.defaultAction)
                    .frame(width: 96)
            }
        }
        .padding(20)
        .frame(width: 520, height: 300)
    }
}

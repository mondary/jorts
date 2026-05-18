import AppKit
import SwiftUI

struct AboutPreferencesView: View {
    private var appName: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Jorts_MacOS" }
    private var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (short?, build?) where !short.isEmpty && !build.isEmpty:
            return "Version \(short) (\(build))"
        case let (short?, _):
            return "Version \(short)"
        case let (_, build?):
            return "Build \(build)"
        default:
            return "Version"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 20) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
                    .cornerRadius(28)

                VStack(alignment: .leading, spacing: 6) {
                    Text(appName)
                        .font(.system(size: 44, weight: .semibold, design: .default))
                        .lineLimit(1)

                    Text(versionString)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    if let copyright = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String,
                       !copyright.isEmpty
                    {
                        Text(copyright)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Links")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 18) {
                        if let url = URL(string: "https://github.com/elly-code/jorts") {
                            Link("Original GitHub", destination: url)
                        }
                        if let url = URL(string: "https://github.com/clm-tmp/JORTS_macos") {
                            Link("macOS Fork GitHub", destination: url)
                        }
                    }
                    .foregroundStyle(.tint)

                    HStack(spacing: 18) {
                        if let url = URL(string: "https://ko-fi.com/teamcons/tip") {
                            Link("Support Original (Ko-fi)", destination: url)
                        }
                        if let url = URL(string: "https://ko-fi.com/pouark") {
                            Link("Support Fork (Ko-fi)", destination: url)
                        }
                    }
                    .foregroundStyle(.tint)
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

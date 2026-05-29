import AppKit
import SwiftUI

struct AboutPreferencesView: View {
    private var appName: String {
        let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        if bundleName == "PKbrain" {
            return "PKbrain"
        }
        return bundleName ?? "PKbrain"
    }
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

    private struct LinkButton: View {
        let title: String
        let subtitle: String
        let systemImage: String
        let url: URL

        var body: some View {
            Link(destination: url) {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 28, height: 28)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center, spacing: 20) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 140, height: 140)
                        .cornerRadius(32)
                        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(appName)
                            .font(.system(size: 48, weight: .semibold, design: .default))
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

                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text(localizedString("links"))
                        .font(.headline)

                    if let url = URL(string: "https://github.com/elly-code/jorts") {
                        LinkButton(
                            title: "GitHub (Original)",
                            subtitle: "Source code and upstream project",
                            systemImage: "chevron.left.slash.chevron.right",
                            url: url
                        )
                    }

                    if let url = URL(string: "https://github.com/clm-tmp/JORTS_macos") {
                        LinkButton(
                            title: "GitHub (macOS Fork)",
                            subtitle: "This fork’s source code",
                            systemImage: "macwindow",
                            url: url
                        )
                    }

                    if let url = URL(string: "https://ko-fi.com/teamcons/tip") {
                        LinkButton(
                            title: "Ko-fi (Original)",
                            subtitle: "Support the original developer",
                            systemImage: "cup.and.saucer.fill",
                            url: url
                        )
                    }

                    if let url = URL(string: "https://ko-fi.com/pouark") {
                        LinkButton(
                            title: "Ko-fi (Fork)",
                            subtitle: "Support this macOS port",
                            systemImage: "cup.and.saucer",
                            url: url
                        )
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
    }
}

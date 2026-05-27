import Foundation

enum InlineBrandIcons {
    struct Badge {
        let title: String
        let iconFile: String?
    }

    private static let explicitAliases: [String: Badge] = [
        "google": Badge(title: "Google", iconFile: "google"),
        "github": Badge(title: "GitHub", iconFile: "github-light"),
        "apple": Badge(title: "Apple", iconFile: "apple-dark"),
        "microsoft": Badge(title: "Microsoft", iconFile: "microsoft"),
        "amazon": Badge(title: "Amazon", iconFile: nil),
        "meta": Badge(title: "Meta", iconFile: "meta"),
        "facebook": Badge(title: "Facebook", iconFile: "facebook"),
        "instagram": Badge(title: "Instagram", iconFile: "instagram"),
        "x": Badge(title: "X", iconFile: "x-dark"),
        "twitter": Badge(title: "X", iconFile: "x-dark"),
        "linkedin": Badge(title: "LinkedIn", iconFile: "linkedin"),
        "youtube": Badge(title: "YouTube", iconFile: "youtube-wordmark"),
        "netflix": Badge(title: "Netflix", iconFile: nil),
        "spotify": Badge(title: "Spotify", iconFile: "spotify"),
        "slack": Badge(title: "Slack", iconFile: "slack"),
        "notion": Badge(title: "Notion", iconFile: "notion"),
        "figma": Badge(title: "Figma", iconFile: "figma"),
        "airbnb": Badge(title: "Airbnb", iconFile: nil),
        "uber": Badge(title: "Uber", iconFile: nil),
        "docker": Badge(title: "Docker", iconFile: "docker"),
        "kubernetes": Badge(title: "Kubernetes", iconFile: "kubernetes"),
        "react": Badge(title: "React", iconFile: "reactjs"),
        "vue": Badge(title: "Vue", iconFile: "vuejs"),
        "angular": Badge(title: "Angular", iconFile: "angular"),
        "swift": Badge(title: "Swift", iconFile: "swift"),
        "typescript": Badge(title: "TypeScript", iconFile: "typescript"),
        "javascript": Badge(title: "JavaScript", iconFile: "javascript"),
        "python": Badge(title: "Python", iconFile: "python"),
        "node": Badge(title: "Node.js", iconFile: "nodejs"),
        "npm": Badge(title: "NPM", iconFile: "npm")
    ]

    static func badge(for token: String) -> Badge? {
        let normalized = normalize(token)
        if let explicit = explicitAliases[normalized] {
            return explicit
        }
        return generatedBadges[normalized]
    }

    static func shouldComplete(after replacement: String) -> Bool {
        guard replacement.count == 1, replacement != "\n", replacement != "\r" else { return false }
        guard let char = replacement.first else { return false }
        return !char.isLetter && !char.isNumber
    }

    private static let generatedBadges: [String: Badge] = {
        guard let directory = Bundle.module.url(forResource: "BrandIcons", withExtension: nil),
              let urls = try? FileManager.default.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: nil
              ) else {
            return [:]
        }

        var result: [String: Badge] = [:]
        for url in urls where url.pathExtension.lowercased() == "svg" {
            let file = url.deletingPathExtension().lastPathComponent
            let title = titleCase(file)
            for token in tokens(for: file) {
                result[token] = Badge(title: title, iconFile: file)
            }
        }
        return result
    }()

    private static func tokens(for file: String) -> Set<String> {
        let rawParts = file
            .lowercased()
            .split(separator: "-")
            .map(String.init)
            .filter { part in
                !["dark", "light", "wordmark", "basic", "2"].contains(part)
            }

        var tokens = Set<String>()
        tokens.insert(normalize(file))
        tokens.insert(rawParts.joined())
        tokens.formUnion(rawParts.map(normalize))
        return tokens.filter { !$0.isEmpty && $0.count > 1 }
    }

    private static func normalize(_ raw: String) -> String {
        raw.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func titleCase(_ raw: String) -> String {
        raw.split(separator: "-")
            .filter { !["dark", "light"].contains($0.lowercased()) }
            .map { part in
                part.prefix(1).uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }
}

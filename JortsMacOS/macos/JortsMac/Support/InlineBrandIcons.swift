import Foundation

enum InlineBrandIcons {
    struct Badge {
        let title: String
        let iconFile: String?
    }

    private static let brandByToken: [String: Badge] = [
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
        brandByToken[token.lowercased()]
    }

    static func shouldComplete(after replacement: String) -> Bool {
        guard replacement.count == 1, replacement != "\n", replacement != "\r" else { return false }
        guard let char = replacement.first else { return false }
        return !char.isLetter && !char.isNumber
    }
}

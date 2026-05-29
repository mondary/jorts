// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "PKbrain",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PKbrain", targets: ["PKbrain"])
    ],
    targets: [
        .executableTarget(
            name: "PKbrain",
            path: "JortsMacOS/macos/JortsMac",
            resources: [
                .copy("Resources/RedactedScript-Regular.ttf"),
                .copy("Resources/BrandIcons"),
                .process("Resources/Localizations")
            ]
        )
    ]
)

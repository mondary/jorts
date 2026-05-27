// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "JortsMac",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "JortsMac", targets: ["JortsMac"])
    ],
    targets: [
        .executableTarget(
            name: "JortsMac",
            path: "JortsMacOS/macos/JortsMac",
            resources: [
                .copy("Resources/RedactedScript-Regular.ttf"),
                .process("Resources/Localizations")
            ]
        )
    ]
)

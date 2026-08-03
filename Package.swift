// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Lite Text Editor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Lite Text Editor", targets: ["LiteTextEditor"])
    ],
    targets: [
        .executableTarget(
            name: "LiteTextEditor",
            path: "Sources/LiteTextEditor",
            exclude: [
                "Resources/.DS_Store",
                "Resources/AppIcon.iconset",
                "Resources/AppIcon.png"
            ],
            resources: [
                .process("Resources/AppIcon.icns")
            ]
        ),
        .testTarget(
            name: "LiteTextEditorTests",
            dependencies: ["LiteTextEditor"],
            path: "Tests/LiteTextEditorTests"
        )
    ]
)

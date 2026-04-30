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
            path: "Sources/LiteTextEditor"
        )
    ]
)

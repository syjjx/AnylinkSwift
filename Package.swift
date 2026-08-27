// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AnyLink",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "AnyLink"
        ),
    ]
)

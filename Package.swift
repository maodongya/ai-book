// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIBook",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "AIBook", targets: ["AIBook"]),
    ],
    targets: [
        .executableTarget(
            name: "AIBook",
            path: "Sources/AIBook",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "AIBookL10nTests",
            dependencies: ["AIBook"],
            path: "Tests/AIBookL10nTests"
        ),
    ]
)

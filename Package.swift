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
        .library(name: "AIBookEvolution", targets: ["AIBookEvolution"]),
    ],
    targets: [
        .target(
            name: "AIBookEvolution",
            path: "Sources/AIBookEvolution"
        ),
        .executableTarget(
            name: "AIBook",
            dependencies: ["AIBookEvolution"],
            path: "Sources/AIBook",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "AIBookEvolutionTests",
            dependencies: ["AIBookEvolution"],
            path: "Tests/AIBookEvolutionTests"
        ),
        .testTarget(
            name: "AIBookL10nTests",
            dependencies: ["AIBook"],
            path: "Tests/AIBookL10nTests"
        ),
    ]
)

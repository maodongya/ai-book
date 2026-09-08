// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIBook",
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
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "AIBookEvolutionTests",
            dependencies: ["AIBookEvolution"],
            path: "Tests/AIBookEvolutionTests"
        ),
    ]
)

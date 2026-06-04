// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIBook",
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
                .copy("Resources"),
            ]
        ),
    ]
)

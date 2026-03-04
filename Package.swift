// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TypingTrainer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TypingTrainer", targets: ["TypingTrainer"])
    ],
    targets: [
        .executableTarget(
            name: "TypingTrainer",
            path: "Sources/TypingTrainer",
            resources: [
                .process("Resources")
            ]
        )
    ]
)

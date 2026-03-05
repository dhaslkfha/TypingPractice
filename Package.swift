// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "TypingTrainer",
    platforms: [
        .macOS(.v12)
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

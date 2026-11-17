// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BookAndQuill",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "BookAndQuill", targets: ["BookAndQuillApp"])
    ],
    targets: [
        // Pure domain: models, limits, page fitting. No UI, no file IO.
        .target(name: "BookCore"),
        // Swappable placeholder textures, font and sounds behind one catalogue.
        .target(name: "BookAssets", resources: [.copy("Assets")]),
        // Repository protocol, file-system implementation and in-memory fake.
        .target(name: "BookStorage", dependencies: ["BookCore"]),
        // Protocol-based sound effects.
        .target(name: "BookAudio", dependencies: ["BookAssets"]),
        // SwiftUI views, view models and the pixel-art theme.
        .target(name: "BookUI", dependencies: ["BookCore", "BookStorage", "BookAudio", "BookAssets"]),
        // Thin entry point: dependency wiring only.
        .executableTarget(name: "BookAndQuillApp", dependencies: ["BookUI", "BookStorage", "BookAudio"]),

        .testTarget(name: "BookCoreTests", dependencies: ["BookCore"]),
        .testTarget(name: "BookStorageTests", dependencies: ["BookStorage", "BookCore"]),
        .testTarget(name: "BookUITests", dependencies: ["BookUI", "BookStorage", "BookCore", "BookAudio", "BookAssets"]),
    ]
)

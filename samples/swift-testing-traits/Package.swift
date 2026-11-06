// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TraitsLab",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "TraitsLab"),
        .testTarget(name: "ParallelTests", dependencies: ["TraitsLab"]),
        .testTarget(name: "TimeLimitTests", dependencies: ["TraitsLab"]),
    ]
)

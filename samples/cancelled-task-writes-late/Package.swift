// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CancelLab",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "CancelLab"),
        .executableTarget(name: "cancel-demo", dependencies: ["CancelLab"]),
        .testTarget(name: "CancelLabTests", dependencies: ["CancelLab"]),
    ]
)

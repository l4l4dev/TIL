// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MainActorLab",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "MainActorLab"),
        .testTarget(name: "ContentionTests", dependencies: ["MainActorLab"]),
        .testTarget(name: "BlockedMainTests", dependencies: ["MainActorLab"]),
    ]
)

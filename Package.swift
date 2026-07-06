// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Restack",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "RestackCore", targets: ["RestackCore"]),
        .library(name: "RestackKit", targets: ["RestackKit"]),
    ],
    targets: [
        .target(name: "RestackCore"),
        .target(name: "RestackKit", dependencies: ["RestackCore"]),
        .testTarget(name: "RestackCoreTests", dependencies: ["RestackCore"]),
        .testTarget(name: "RestackKitTests", dependencies: ["RestackKit", "RestackCore"]),
    ]
)

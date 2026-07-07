// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Restack",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "RestackCore", targets: ["RestackCore"]),
        .library(name: "RestackKit", targets: ["RestackKit"]),
        .executable(name: "RestackApp", targets: ["RestackApp"]),
    ],
    targets: [
        .target(name: "RestackCore"),
        .target(name: "RestackKit", dependencies: ["RestackCore"]),
        .executableTarget(
            name: "RestackApp",
            dependencies: ["RestackCore", "RestackKit"],
            path: "App",
            exclude: ["Info.plist", "README.md"]
        ),
        .testTarget(name: "RestackCoreTests", dependencies: ["RestackCore"]),
        .testTarget(name: "RestackKitTests", dependencies: ["RestackKit", "RestackCore"]),
    ]
)

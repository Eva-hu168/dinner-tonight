// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DinnerCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "DinnerCore", targets: ["DinnerCore"])],
    targets: [
        .target(name: "DinnerCore", resources: [.process("Resources")]),
        .testTarget(name: "DinnerCoreTests", dependencies: ["DinnerCore"]),
    ]
)

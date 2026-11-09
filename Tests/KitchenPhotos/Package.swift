// swift-tools-version: 6.0
import PackageDescription

// Builds the App's photo scanner (symlinked from App/) on macOS, so real photos can run through it.
let package = Package(
    name: "KitchenPhotos",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../../Packages/DinnerCore")],
    targets: [
        .target(name: "KitchenScanning", dependencies: ["DinnerCore"]),
        .testTarget(name: "KitchenPhotoTests", dependencies: ["KitchenScanning", "DinnerCore"],
                    resources: [.copy("../../Photos")]),
    ]
)

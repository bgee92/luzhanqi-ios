// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LuzhanqiKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LuzhanqiKit", targets: ["LuzhanqiKit"]),
    ],
    targets: [
        .target(name: "LuzhanqiKit"),
        .testTarget(name: "LuzhanqiKitTests", dependencies: ["LuzhanqiKit"]),
    ]
)

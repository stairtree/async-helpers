// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "async-helpers",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .library(name: "AsyncHelpers", targets: ["AsyncHelpers"]),
    ],
    targets: [
        .target(
            name: "AsyncHelpers",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        ),
    ]
)

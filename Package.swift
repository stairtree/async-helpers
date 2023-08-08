// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "async-helpers",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(
            name: "AsyncHelpers",
            targets: ["AsyncHelpers"]),
    ],
    targets: [
        .target(name: "AsyncHelpers"),
    ]
)

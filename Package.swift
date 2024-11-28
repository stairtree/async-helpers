// swift-tools-version:6.0
//===----------------------------------------------------------------------===//
//
// This source file is part of the AsyncHelpers open source project
//
// Copyright (c) Stairtree GmbH
// Licensed under the MIT license
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
]

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
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AsyncHelpersTests",
            dependencies: [
                .target(name: "AsyncHelpers"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)

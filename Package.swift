// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Gesso",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "GessoCore",
            targets: ["GessoCore"]),
    ],
    dependencies: [
        // Add any external dependencies here
    ],
    targets: [
        .target(
            name: "GessoCore",
            dependencies: []),
        .testTarget(
            name: "GessoCoreTests",
            dependencies: ["GessoCore"]),
    ]
)

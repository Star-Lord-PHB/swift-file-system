// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-file-system",
    platforms: [.macOS(.v10_15), .iOS(.v13), .watchOS(.v6), .tvOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FileSystem",
            targets: ["FileSystem"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-system.git", from: "1.6.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FileSystem",
            dependencies: [
                .product(name: "SystemPackage", package: "swift-system"),
                "CFileSystem"
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("NonescapableTypes"),
                .enableExperimentalFeature("NoncopyableGenerics")
            ]
        ),
        .target(
            name: "CFileSystem",
            publicHeadersPath: ""
        ),
        .testTarget(
            name: "FileSystemTests",
            dependencies: ["FileSystem"]
        ),
    ]
)
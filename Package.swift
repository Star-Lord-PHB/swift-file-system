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
        .package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "1.29.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FileSystem",
            dependencies: [
                .product(name: "SystemPackage", package: "swift-system"),
                "CFileSystem",
                "PlatformCLib"
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
        .target(
            name: "PlatformCLib"
        ),
        .testTarget(
            name: "FileSystemTests",
            dependencies: ["FileSystem"]
        ),
    ]
)


if #available(macOS 13, iOS 16, watchOS 9, tvOS 16, *) {
    package.platforms = [.macOS(.v13), .iOS(.v16), .watchOS(.v9), .tvOS(.v16)]
    // Benchmark of FileSystemBenchmark
    package.targets += [
        .executableTarget(
            name: "FileSystemBenchmark",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                "FileSystem"
            ],
            path: "Benchmarks/FileSystemBenchmark",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
    ]
}
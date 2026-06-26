// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-file-system",
    platforms: [.macOS(.v10_15), .iOS(.v13), .watchOS(.v6), .tvOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftFileSystem",
            targets: ["SwiftFileSystem"]
        ),
        .library(
            name: "FileSystemCore",
            targets: ["FileSystemCore"]
        ),
        .library(
            name: "SwiftFileSystemFoundationCompat",
            targets: ["SwiftFileSystemFoundationCompat"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-system.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.3.0"),
        // .package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "1.29.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftFileSystem",
            dependencies: [
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "BasicContainers", package: "swift-collections"),
                "CFileSystem",
                "PlatformCLib",
                "FileSystemCore"
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("NonescapableTypes"),
                .enableExperimentalFeature("NoncopyableGenerics"),
                .enableExperimentalFeature("BorrowingSwitch"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults")
            ]
        ),
        .target(
            name: "FileSystemCore", 
            dependencies: [
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "BasicContainers", package: "swift-collections"),
                "CFileSystem",
                "PlatformCLib"
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("NonescapableTypes"),
                .enableExperimentalFeature("NoncopyableGenerics"),
                .enableExperimentalFeature("BorrowingSwitch"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults")
            ]
        ),
        .target(
            name: "SwiftFileSystemFoundationCompat",
            dependencies: ["SwiftFileSystem"]),
        .target(
            name: "CFileSystem",
            publicHeadersPath: ""
        ),
        .target(
            name: "PlatformCLib",
            dependencies: ["CFileSystem"]
        ),
        .testTarget(
            name: "FileSystemTests",
            dependencies: ["SwiftFileSystem", "SwiftFileSystemFoundationCompat"]
        ),
    ]
)


#if canImport(Darwin)
if #available(macOS 13, iOS 16, watchOS 9, tvOS 16, *) {
    // MARK: TODO: Consider adding a Environment variable to control whether to include the benchmark target.
    package.dependencies.append(.package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "1.29.0")))
    package.platforms = [.macOS(.v13), .iOS(.v16), .watchOS(.v9), .tvOS(.v16)]
    // Benchmark of FileSystemBenchmark
    package.targets += [
        .executableTarget(
            name: "FileSystemBenchmark",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                "SwiftFileSystem"
            ],
            path: "Benchmarks/FileSystemBenchmark",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("NonescapableTypes"),
            ],
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ],
        ),
    ]
}
#endif 

// swift-tools-version: 5.9
// designmd — a Swift port of the DESIGN.md linter/exporter, Apple-flavored.
import PackageDescription

let package = Package(
    name: "designmd",
    products: [
        .library(name: "DesignMD", targets: ["DesignMD"]),
        .executable(name: "designmd", targets: ["DesignMDCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "DesignMD",
            dependencies: ["Yams"],
            resources: [.copy("Resources")]
        ),
        .executableTarget(
            name: "DesignMDCLI",
            dependencies: [
                "DesignMD",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/CLI"
        ),
        .testTarget(
            name: "DesignMDTests",
            dependencies: ["DesignMD"],
            resources: [.copy("Fixtures")]
        ),
    ]
)

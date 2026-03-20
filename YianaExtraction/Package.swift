// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "YianaExtraction",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "YianaExtraction", targets: ["YianaExtraction"]),
        .executable(name: "yiana-extract", targets: ["YianaExtractCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.7.0"),
    ],
    targets: [
        .target(
            name: "YianaExtraction",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .executableTarget(
            name: "YianaExtractCLI",
            dependencies: ["YianaExtraction"],
            path: "Sources/YianaExtractCLI"
        ),
        .testTarget(
            name: "YianaExtractionTests",
            dependencies: ["YianaExtraction"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)

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
    ],
    targets: [
        .target(
            name: "YianaExtraction"
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

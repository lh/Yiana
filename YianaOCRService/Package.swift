// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YianaOCRService",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "yiana-ocr",
            targets: ["YianaOCRService"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "YianaOCRService",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "YianaOCRServiceTests",
            dependencies: ["YianaOCRService"],
            path: "Tests/YianaOCRServiceTests"
        ),
    ]
)

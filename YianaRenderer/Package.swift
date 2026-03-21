// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "YianaRenderer",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "YianaRenderer", targets: ["YianaRenderer"]),
    ],
    targets: [
        .binaryTarget(
            name: "CYianaTypstBridge",
            path: "rust/yiana-typst-bridge/YianaTypstBridge.xcframework"
        ),
        .target(
            name: "YianaRenderer",
            dependencies: ["CYianaTypstBridge"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "YianaRendererTests",
            dependencies: ["YianaRenderer"]
        ),
    ]
)

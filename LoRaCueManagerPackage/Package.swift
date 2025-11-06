// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LoRaCueManagerPackage",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "LoRaCueManagerFeature",
            targets: ["LoRaCueManagerFeature"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ChimeHQ/JSONRPC", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "LoRaCueManagerFeature",
            dependencies: [
                .product(name: "JSONRPC", package: "JSONRPC")
            ],
            path: "Sources/LoRaCueManagerFeature"
        ),
        .testTarget(
            name: "LoRaCueManagerFeatureTests",
            dependencies: ["LoRaCueManagerFeature"],
            path: "Tests/LoRaCueManagerFeatureTests"
        )
    ]
)

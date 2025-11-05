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
    targets: [
        .target(
            name: "LoRaCueManagerFeature",
            path: "Sources/LoRaCueManagerFeature"
        ),
        .testTarget(
            name: "LoRaCueManagerFeatureTests",
            dependencies: ["LoRaCueManagerFeature"],
            path: "Tests/LoRaCueManagerFeatureTests"
        )
    ]
)

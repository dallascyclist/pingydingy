// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PingyDingy",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "PingyDingy",
            path: "PingyDingy",
            resources: [
                .copy("../Sounds"),
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "PingyDingyTests",
            dependencies: ["PingyDingy"],
            path: "PingyDingyTests"
        )
    ]
)

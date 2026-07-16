// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexMeter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodexMeter", targets: ["CodexMeter"])
    ],
    targets: [
        .executableTarget(name: "CodexMeter"),
        .testTarget(
            name: "CodexMeterTests",
            dependencies: ["CodexMeter"]
        )
    ]
)

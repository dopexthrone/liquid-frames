// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "liquid-frames",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "liquid-frames", targets: ["liquid-frames"])
    ],
    targets: [
        .executableTarget(
            name: "liquid-frames"),
    ]
)

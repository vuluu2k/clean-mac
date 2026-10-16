// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "clean-mac",
    defaultLocalization: "vi",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CleanMacCore", targets: ["CleanMacCore"]),
        .executable(name: "CleanMac", targets: ["CleanMac"])
    ],
    targets: [
        .target(name: "CleanMacCore", resources: [.process("Resources")]),
        .executableTarget(name: "CleanMac", dependencies: ["CleanMacCore"]),
        .testTarget(name: "CleanMacCoreTests", dependencies: ["CleanMacCore", "CleanMac"])
    ]
)

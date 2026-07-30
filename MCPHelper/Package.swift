// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "GodexUMCPHelper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "GodexUMCPCore", targets: ["GodexUMCPCore"]),
        .executable(
            name: "GodexUMCPContractTests",
            targets: ["GodexUMCPContractTests"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/modelcontextprotocol/swift-sdk.git",
            exact: "0.12.1"
        )
    ],
    targets: [
        .target(name: "GodexUMCPCore"),
        .executableTarget(
            name: "GodexUMCPContractTests",
            dependencies: ["GodexUMCPCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)

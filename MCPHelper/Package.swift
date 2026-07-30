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
        ),
        .executable(
            name: "GodexUMCPProbe",
            targets: ["GodexUMCPProbe"]
        ),
        .executable(
            name: "GodexUMCPServer",
            targets: ["GodexUMCPServer"]
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
        ),
        .executableTarget(
            name: "GodexUMCPProbe"
        ),
        .executableTarget(
            name: "GodexUMCPServer",
            dependencies: [
                "GodexUMCPCore",
                .product(name: "MCP", package: "swift-sdk")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)

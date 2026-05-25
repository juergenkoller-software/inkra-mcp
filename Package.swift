// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "InkraMCP",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "InkraMCP", targets: ["InkraMCP"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0")
    ],
    targets: [
        .executableTarget(
            name: "InkraMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/InkraMCP"
        )
    ]
)

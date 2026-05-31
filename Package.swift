// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CLIApprovalFloat",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ApprovalFloat", targets: ["ApprovalFloat"])
    ],
    targets: [
        .target(name: "ApprovalFloatCore"),
        .executableTarget(
            name: "ApprovalFloat",
            dependencies: ["ApprovalFloatCore"]
        ),
        .testTarget(
            name: "ApprovalFloatCoreTests",
            dependencies: ["ApprovalFloatCore"]
        )
    ]
)

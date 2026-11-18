// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OmnissaBetaTokens",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "BetaTokensCore", targets: ["BetaTokensCore"]),
        .executable(name: "OmnissaBetaTokens", targets: ["OmnissaBetaTokensApp"]),
    ],
    targets: [
        .target(name: "BetaTokensCore"),
        .executableTarget(name: "OmnissaBetaTokensApp", dependencies: ["BetaTokensCore"]),
        .testTarget(name: "BetaTokensCoreTests", dependencies: ["BetaTokensCore"]),
    ]
)

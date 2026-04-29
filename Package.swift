// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PromtSidecar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PromtSidecar",
            path: "Sources/PromtSidecar"
        )
    ]
)

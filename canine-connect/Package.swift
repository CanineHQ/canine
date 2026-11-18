// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CanineConnect",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CanineConnect",
            path: "Sources/CanineConnect"
        )
    ]
)

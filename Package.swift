// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenshotApp",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ScreenshotApp",
            path: "ScreenshotApp",
            exclude: ["Info.plist"]
        ),
    ]
)

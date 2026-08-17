// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GyazoCapture",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "GyazoCapture", targets: ["GyazoCapture"])
    ],
    targets: [
        .executableTarget(
            name: "GyazoCapture",
            path: "Sources/GyazoCapture"
        )
    ],
    swiftLanguageModes: [.v5]
)

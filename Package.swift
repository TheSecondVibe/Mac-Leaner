// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacLeaner",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacLeaner", targets: ["MacLeaner"])
    ],
    targets: [
        .executableTarget(name: "MacLeaner"),
        .testTarget(name: "MacLeanerTests", dependencies: ["MacLeaner"]),
    ],
    swiftLanguageModes: [.v6]
)

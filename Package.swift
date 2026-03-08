// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RSSReader",
    platforms: [
        .macOS(.v14)  // Minimum v14; Apple Intelligence #available(macOS 15, *) ile runtime'da kontrol edilir
    ],
    dependencies: [
        .package(url: "https://github.com/nmdias/FeedKit.git", from: "9.1.2"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.5")
    ],
    targets: [
        .executableTarget(
            name: "RSSReader",
            dependencies: [
                .product(name: "FeedKit", package: "FeedKit"),
                .product(name: "SwiftSoup", package: "SwiftSoup")
            ],
            path: "Sources/RSSReader"
        )
    ]
)


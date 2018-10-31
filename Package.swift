// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HttpServer",
    products: [
        .library(
            name: "HttpServer",
            targets: ["HttpServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.9.5"),
    ],
    targets: [
        .target(
            name: "HttpServer",
            dependencies: ["NIO","NIOHTTP1"]),
        .testTarget(
            name: "HttpServerTests",
            dependencies: ["HttpServer"]),
    ]
)

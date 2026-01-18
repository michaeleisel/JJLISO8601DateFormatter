// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JJLISO8601DateFormatter",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "JJLISO8601DateFormatter",
            targets: ["JJLISO8601DateFormatter"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // C target with internal implementation
        .target(
            name: "JJLInternal",
            dependencies: [],
            cSettings: [
                .headerSearchPath("Vendor/tzdb"),
            ]),
        // Swift target with public API
        .target(
            name: "JJLISO8601DateFormatter",
            dependencies: ["JJLInternal"]),
        .testTarget(
            name: "JJLISO8601DateFormatterTests",
            dependencies: ["JJLISO8601DateFormatter"]),
        .testTarget(
            name: "JJLISO8601DateFormatterSwiftBenchTests",
            dependencies: ["JJLISO8601DateFormatter"]),
        .executableTarget(
            name: "Benchmark",
            dependencies: ["JJLISO8601DateFormatter"]),
    ]
)

// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JJLISO8601DateFormatter",
    products: [
        .library(
            name: "JJLISO8601DateFormatter",
            targets: ["JJLISO8601DateFormatter"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "tzdb",
            dependencies: [],
            path: "Sources/tzdb",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("."),
            ]
        ),
        .target(
            name: "JJLInternal",
            dependencies: ["tzdb"],
            path: "Sources/JJLInternal",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("."),
            ]
        ),
        .target(
            name: "JJLISO8601DateFormatter",
            dependencies: ["JJLInternal"],
            path: "Sources/JJLISO8601DateFormatter"),
        .testTarget(
            name: "JJLISO8601DateFormatterTests",
            dependencies: ["JJLISO8601DateFormatter"],
            cSettings: [
                .headerSearchPath("include"),
            ]
        ),
    ]
)

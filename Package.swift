// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JJLISO8601DateFormatter",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "JJLISO8601DateFormatter",
            targets: ["JJLISO8601DateFormatter"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "JJLISO8601DateFormatter",
            dependencies: [],
            publicHeadersPath: "include",
            cxxSettings: [
                .unsafeFlags(["-std=c++20"]),
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
            ]
        ),
        .testTarget(
            name: "JJLISO8601DateFormatterTests",
            dependencies: ["JJLISO8601DateFormatter"]
        ),
        .testTarget(
            name: "JJLISO8601DateFormatterSwiftBenchTests",
            dependencies: ["JJLISO8601DateFormatter"]
        ),
    ],
    cxxLanguageStandard: .cxx20
)

// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "JJLISO8601DateFormatterBenchmark",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "BenchmarkCore",
            targets: ["BenchmarkCore"]
        ),
        .executable(
            name: "BenchmarkCLI",
            targets: ["BenchmarkCLI"]
        )
    ],
    dependencies: [
        .package(path: "..")
    ],
    targets: [
        .target(
            name: "BenchmarkCore",
            dependencies: ["JJLISO8601DateFormatter"]
        ),
        .executableTarget(
            name: "BenchmarkCLI",
            dependencies: ["BenchmarkCore"]
        )
    ]
)

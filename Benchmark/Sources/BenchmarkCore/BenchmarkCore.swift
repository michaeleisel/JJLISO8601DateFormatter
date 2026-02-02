import Foundation
import JJLISO8601DateFormatter

public enum BenchmarkCategory: String, CaseIterable, Sendable {
    case jjl = "JJLISO8601DateFormatter"
    case iso8601FormatStyle = "ISO8601FormatStyle"
    case formatStyle = "FormatStyle"
    case iso8601DateFormatter = "ISO8601DateFormatter"
}

public enum BenchmarkOperation: String, CaseIterable, Sendable {
    case dateToString = "Date -> String"
    case stringToDate = "String -> Date"
}

public struct BenchmarkResult: Sendable, Identifiable {
    public let operation: BenchmarkOperation
    public let category: BenchmarkCategory
    public let runsPerSecond: Double

    public var id: String {
        "\(operation.rawValue)-\(category.rawValue)"
    }
}

public struct BenchmarkReport: Sendable {
    public let results: [BenchmarkResult]
    public let iterationsPerBatch: Int
    public let targetSeconds: Double
    public let sampleStrings: [String]

    public func result(for operation: BenchmarkOperation, category: BenchmarkCategory) -> BenchmarkResult? {
        results.first { $0.operation == operation && $0.category == category }
    }

    public func results(for operation: BenchmarkOperation) -> [BenchmarkResult] {
        results.filter { $0.operation == operation }
    }

    public func markdownTable(operation: BenchmarkOperation, baseline: BenchmarkCategory = .iso8601DateFormatter) -> String {
        var lines: [String] = []
        lines.append("| API | Runs/sec | Speedup vs \(baseline.rawValue) |")
        lines.append("| --- | ---: | ---: |")

        let baselineValue = result(for: operation, category: baseline)?.runsPerSecond
        for category in BenchmarkCategory.allCases {
            guard let result = result(for: operation, category: category) else { continue }
            let speedup: String
            if let baselineValue, baselineValue > 0 {
                let value = result.runsPerSecond / baselineValue
                speedup = String(format: "%.2fx", value)
            } else {
                speedup = "n/a"
            }
            lines.append("| \(category.rawValue) | \(String(format: "%.2f", result.runsPerSecond)) | \(speedup) |")
        }

        return lines.joined(separator: "\n")
    }
}

public struct BenchmarkRunner: Sendable {
    public var iterationsPerBatch: Int
    public var targetSeconds: Double
    public var dateStrings: [String]
    public var sampleDate: Date
    public var timeZone: TimeZone

    public init(
        iterationsPerBatch: Int = 1000,
        targetSeconds: Double = 1.0,
        dateStrings: [String] = [
            "2018-09-13T19:56:48.980Z",
            "2018-09-13T16:56:48.980-03:00",
            "2018-09-14T04:56:48.980+09:00"
        ],
        sampleDate: Date? = nil,
        timeZone: TimeZone = TimeZone(secondsFromGMT: -3 * 3600)!
    ) {
        self.iterationsPerBatch = max(1, iterationsPerBatch)
        self.targetSeconds = max(0.01, targetSeconds)
        self.dateStrings = dateStrings
        self.sampleDate = sampleDate ?? Self.defaultSampleDate(from: dateStrings)
        self.timeZone = timeZone
    }

    public func run() -> BenchmarkReport {
        let formatOptions: ISO8601DateFormatter.Options = [
            .withInternetDateTime,
            .withFractionalSeconds,
            .withColonSeparatorInTimeZone
        ]

        let jjlFormatter = JJLISO8601DateFormatter()
        jjlFormatter.timeZone = timeZone
        jjlFormatter.formatOptions = formatOptions

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = timeZone
        isoFormatter.formatOptions = formatOptions

        let iso8601Style = makeISO8601FormatStyle()
        let iso8601ParseStrategy = iso8601Style.parseStrategy

        let expectedDates: [Date] = dateStrings.compactMap { isoFormatter.date(from: $0) }
        hardAssert(expectedDates.count == dateStrings.count, "Failed to parse sample strings")

        var results: [BenchmarkResult] = []
        results.append(runDateToString(
            category: .jjl,
            test: {
                let string = jjlFormatter.string(from: sampleDate)
                guard let parsed = isoFormatter.date(from: string) else { return false }
                return datesMatch(parsed, sampleDate)
            },
            block: {
                for _ in 0..<iterationsPerBatch {
                    let value = jjlFormatter.string(from: sampleDate)
                    blackHole(value)
                }
            }
        ))

        results.append(runDateToString(
            category: .iso8601DateFormatter,
            test: {
                let string = isoFormatter.string(from: sampleDate)
                guard let parsed = isoFormatter.date(from: string) else { return false }
                return datesMatch(parsed, sampleDate)
            },
            block: {
                for _ in 0..<iterationsPerBatch {
                    let value = isoFormatter.string(from: sampleDate)
                    blackHole(value)
                }
            }
        ))

        results.append(runDateToString(
            category: .iso8601FormatStyle,
            test: {
                let string = sampleDate.formatted(iso8601Style)
                guard let parsed = try? Date(string, strategy: iso8601ParseStrategy) else { return false }
                return datesMatch(parsed, sampleDate)
            },
            block: {
                for _ in 0..<iterationsPerBatch {
                    let value = sampleDate.formatted(iso8601Style)
                    blackHole(value)
                }
            }
        ))

        results.append(runDateToString(
            category: .formatStyle,
            test: {
                let style = makeISO8601FormatStyle()
                let string = sampleDate.formatted(style)
                guard let parsed = try? Date(string, strategy: style) else { return false }
                return datesMatch(parsed, sampleDate)
            },
            block: {
                for _ in 0..<iterationsPerBatch {
                    let style = makeISO8601FormatStyle()
                    let value = sampleDate.formatted(style)
                    blackHole(value)
                }
            }
        ))

        results.append(runStringToDate(
            category: .jjl,
            test: {
                for (string, expected) in zip(dateStrings, expectedDates) {
                    guard let parsed = jjlFormatter.date(from: string) else { return false }
                    if !datesMatch(parsed, expected) { return false }
                }
                return true
            },
            block: {
                for index in 0..<iterationsPerBatch {
                    let string = dateStrings[index % dateStrings.count]
                    let value = jjlFormatter.date(from: string)
                    blackHole(value)
                }
            }
        ))

        results.append(runStringToDate(
            category: .iso8601DateFormatter,
            test: {
                for (string, expected) in zip(dateStrings, expectedDates) {
                    guard let parsed = isoFormatter.date(from: string) else { return false }
                    if !datesMatch(parsed, expected) { return false }
                }
                return true
            },
            block: {
                for index in 0..<iterationsPerBatch {
                    let string = dateStrings[index % dateStrings.count]
                    let value = isoFormatter.date(from: string)
                    blackHole(value)
                }
            }
        ))

        results.append(runStringToDate(
            category: .iso8601FormatStyle,
            test: {
                for (string, expected) in zip(dateStrings, expectedDates) {
                    guard let parsed = try? Date(string, strategy: iso8601ParseStrategy) else { return false }
                    if !datesMatch(parsed, expected) { return false }
                }
                return true
            },
            block: {
                for index in 0..<iterationsPerBatch {
                    let string = dateStrings[index % dateStrings.count]
                    let value = try? Date(string, strategy: iso8601ParseStrategy)
                    blackHole(value)
                }
            }
        ))

        results.append(runStringToDate(
            category: .formatStyle,
            test: {
                for (string, expected) in zip(dateStrings, expectedDates) {
                    let style = makeISO8601FormatStyle()
                    guard let parsed = try? Date(string, strategy: style) else { return false }
                    if !datesMatch(parsed, expected) { return false }
                }
                return true
            },
            block: {
                for index in 0..<iterationsPerBatch {
                    let style = makeISO8601FormatStyle()
                    let string = dateStrings[index % dateStrings.count]
                    let value = try? Date(string, strategy: style)
                    blackHole(value)
                }
            }
        ))

        return BenchmarkReport(
            results: results,
            iterationsPerBatch: iterationsPerBatch,
            targetSeconds: targetSeconds,
            sampleStrings: dateStrings
        )
    }

    private func runDateToString(
        category: BenchmarkCategory,
        test: () -> Bool,
        block: () -> Void
    ) -> BenchmarkResult {
        let rate = benchmark(name: "\(BenchmarkOperation.dateToString.rawValue) - \(category.rawValue)", test: test, block: block)
        return BenchmarkResult(operation: .dateToString, category: category, runsPerSecond: rate)
    }

    private func runStringToDate(
        category: BenchmarkCategory,
        test: () -> Bool,
        block: () -> Void
    ) -> BenchmarkResult {
        let rate = benchmark(name: "\(BenchmarkOperation.stringToDate.rawValue) - \(category.rawValue)", test: test, block: block)
        return BenchmarkResult(operation: .stringToDate, category: category, runsPerSecond: rate)
    }

    private func benchmark(name: String, test: () -> Bool, block: () -> Void) -> Double {
        if isInDebug() {
            print("WARNING: in debug mode")
        }
        hardAssert(test(), "Benchmark test failed: \(name)")
        blackHole(block())

        var totalElapsed = 0.0
        var runs: UInt64 = 0

        while totalElapsed < targetSeconds || runs == 0 {
            let start = currentTime()
            autoreleasepool {
                block()
            }
            let end = currentTime()
            totalElapsed += (end - start)
            runs += 1
        }

        let totalOps = Double(runs) * Double(iterationsPerBatch)
        return totalOps / totalElapsed
    }

    private func makeISO8601FormatStyle() -> Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(
            dateSeparator: .dash,
            dateTimeSeparator: .standard,
            timeSeparator: .colon,
            timeZoneSeparator: .colon,
            includingFractionalSeconds: true,
            timeZone: timeZone
        )
    }

    private static func defaultSampleDate(from dateStrings: [String]) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
            .withColonSeparatorInTimeZone
        ]
        if let first = dateStrings.first, let parsed = formatter.date(from: first) {
            return parsed
        }
        return Date(timeIntervalSince1970: 1536868608.98)
    }
}

@inline(__always)
private func currentTime() -> Double {
    var ts = timespec()
    clock_gettime(CLOCK_MONOTONIC, &ts)
    return Double(ts.tv_sec) + Double(ts.tv_nsec) / 1_000_000_000
}

private func isInDebug() -> Bool {
    #if DEBUG
    return true
    #else
    return false
    #endif
}

@inline(never)
@_optimize(none)
public func blackHole<T>(_ value: T) {
}

@inline(__always)
private func hardAssert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "") {
    if !condition() {
        fatalError("Assertion failed: \(message())")
    }
}

@inline(__always)
private func datesMatch(_ lhs: Date, _ rhs: Date) -> Bool {
    abs(lhs.timeIntervalSince1970 - rhs.timeIntervalSince1970) < 0.000_5
}

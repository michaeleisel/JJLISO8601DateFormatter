// Copyright (c) 2018 Michael Eisel. All rights reserved.

import Foundation
import JJLISO8601DateFormatter

// MARK: - Assertion

@inline(__always)
func hardAssert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    if !condition() {
        fatalError("Assertion failed: \(message())", file: file, line: line)
    }
}

// MARK: - Timing

@inline(__always)
private func currentTime() -> Double {
    var ts = timespec()
    clock_gettime(CLOCK_MONOTONIC, &ts)
    return Double(ts.tv_sec) + Double(ts.tv_nsec) / 1e9
}

// MARK: - Benchmark

private func benchmark(_ name: String, test: (() -> Bool)? = nil, block: () -> Void) {
    if let test = test {
        hardAssert(test(), "Test failed for benchmark: \(name)")
    }
    block()
    
    var totalElapsed = 0.0
    var runs: UInt64 = 0
    let targetSeconds = 1.0
    
    while totalElapsed < targetSeconds {
        let start = currentTime()
        autoreleasepool {
            block()
        }
        let end = currentTime()
        
        totalElapsed += (end - start)
        runs += 1
    }
    
    let runsPerSecond = Double(runs) / totalElapsed
    
    print("\(name): \(String(format: "%.2f", runsPerSecond)) runs/sec")
}

// MARK: - Benchmarks

func dateFromStringBenchmark() {
    print("=== dateFromString Benchmark ===")
    
    for timeZone: TimeZone? in [
        nil,
        TimeZone(secondsFromGMT: 0)!,
        TimeZone(secondsFromGMT: 1)!,
        TimeZone(identifier: "UTC")!,
        TimeZone(identifier: "America/Sao_Paulo")!
    ] {
        let jjlFormatter = JJLISO8601DateFormatter()
        jjlFormatter.formatOptions.insert(.withFractionalSeconds)
        jjlFormatter.timeZone = timeZone ?? TimeZone(secondsFromGMT: 0)!
        
        let appleFormatter = ISO8601DateFormatter()
        appleFormatter.formatOptions.insert(.withFractionalSeconds)
        appleFormatter.timeZone = timeZone
        
        let dateString = "2018-09-13T19:56:48.981Z"
        let tzName = timeZone?.identifier ?? "nil"
        
        benchmark("JJL dateFromString [\(tzName)]", test: {
            return jjlFormatter.date(from: dateString) == appleFormatter.date(from: dateString)
        }) {
            for _ in 0..<1000 {
                _ = jjlFormatter.date(from: dateString)
            }
        }

        benchmark("Apple dateFromString [\(tzName)]") {
            for _ in 0..<1000 {
                _ = appleFormatter.date(from: dateString)
            }
        }
    }
}

func stringFromDateBenchmark() {
    print("\n=== stringFromDate Benchmark ===")
    
    let jjlFormatter = JJLISO8601DateFormatter()
    jjlFormatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    jjlFormatter.formatOptions.insert(.withFractionalSeconds)
    
    let appleFormatter = ISO8601DateFormatter()
    appleFormatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    appleFormatter.formatOptions.insert(.withFractionalSeconds)
    
    let date = Date(timeIntervalSince1970: 1536868608.981)
    
    benchmark("JJL stringFromDate", test: {
        return jjlFormatter.string(from: date) == appleFormatter.string(from: date)
    }) {
        for _ in 0..<1000 {
            _ = jjlFormatter.string(from: date)
        }
    }
    
    benchmark("Apple stringFromDate") {
        for _ in 0..<1000 {
            _ = appleFormatter.string(from: date)
        }
    }
}

func formatStyleBenchmark() {
    print("\n=== FormatStyle Benchmark ===")
    
    let jjlFormatter = JJLISO8601DateFormatter()
    jjlFormatter.formatOptions.insert(.withFractionalSeconds)
    
    let date = Date(timeIntervalSince1970: 1536868608.981)
    let formatStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    
    benchmark("JJL stringFromDate") {
        for _ in 0..<1000 {
            _ = jjlFormatter.string(from: date)
        }
    }
    
    benchmark("Date.ISO8601FormatStyle formatted") {
        for _ in 0..<1000 {
            _ = date.formatted(formatStyle)
        }
    }
    
    let dateString = "2018-09-13T19:56:48.981Z"
    let parseStrategy = Date.ISO8601FormatStyle(includingFractionalSeconds: true).parseStrategy
    
    benchmark("JJL dateFromString") {
        for _ in 0..<1000 {
            _ = jjlFormatter.date(from: dateString)
        }
    }
    
    benchmark("Date.ISO8601FormatStyle parse") {
        for _ in 0..<1000 {
            _ = try? Date(dateString, strategy: parseStrategy)
        }
    }
}

// MARK: - Main

print("JJLISO8601DateFormatter Benchmark")
print("==================================\n")

dateFromStringBenchmark()
stringFromDateBenchmark()
formatStyleBenchmark()

print("\n✓ All benchmarks completed successfully")

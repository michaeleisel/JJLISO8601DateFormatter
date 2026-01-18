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

private func isInDebug() -> Bool {
    #if DEBUG
    return true
    #else
    return false
    #endif
}

private func benchmark(_ name: String, test: (() -> Bool)? = nil, block: () -> Void) {
    if isInDebug() {
        print("WARNING: in debug mode")
    }
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
    
    let dateString = "2018-09-13T19:56:48.981"
    
    let timeZones: [TimeZone] = [
        TimeZone(secondsFromGMT: 0)!,
        TimeZone(identifier: "America/Sao_Paulo")!,
        TimeZone(identifier: "Asia/Tokyo")!,
    ]
    
    for timeZone in timeZones {
        let jjlFormatter = JJLISO8601DateFormatter()
        jjlFormatter.formatOptions.insert(.withFractionalSeconds)
        jjlFormatter.timeZone = timeZone
        
        let parseStrategy = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: timeZone)
            .parseStrategy
        
        let tzName = timeZone.identifier
        
        benchmark("JJL dateFromString [\(tzName)]", test: {
            let jjlDate = jjlFormatter.date(from: dateString)
            let appleDate = try? Date(dateString, strategy: parseStrategy)
            return jjlDate == appleDate
        }) {
            for _ in 0..<1000 {
                _ = jjlFormatter.date(from: dateString)
            }
        }

        /*benchmark("ISO8601FormatStyle parse [\(tzName)]") {
            for _ in 0..<1000 {
                _ = try? Date(dateString, strategy: parseStrategy)
            }
        }*/
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
//stringFromDateBenchmark()
//formatStyleBenchmark()

print("\n✓ All benchmarks completed successfully")

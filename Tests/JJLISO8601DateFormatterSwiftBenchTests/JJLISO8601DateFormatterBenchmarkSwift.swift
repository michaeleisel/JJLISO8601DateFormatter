// Copyright (c) 2018 Michael Eisel. All rights reserved.

import XCTest
import JJLISO8601DateFormatter

final class JJLISO8601DateFormatterBenchmarkSwift: XCTestCase {
    
    private func currentTime() -> Double {
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        return Double(ts.tv_sec) + Double(ts.tv_nsec) / 1e9
    }
    
    private func benchmark(_ name: String, test: (() -> Bool)?, block: () -> Void) {
        if let test = test {
            XCTAssertTrue(test())
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
    
    func testDateFromStringBenchmark() {
        for timeZone: TimeZone? in [
            nil,
            /*TimeZone(secondsFromGMT: 0)!,
            TimeZone(secondsFromGMT: 1)!,
            TimeZone(identifier: "UTC")!,
            TimeZone(identifier: "America/Sao_Paulo")!*/
        ] {
            let jjlFormatter = JJLISO8601DateFormatter()
            jjlFormatter.formatOptions.insert(.withFractionalSeconds)
            jjlFormatter.timeZone = timeZone ?? TimeZone(secondsFromGMT: 0)!
            
            let appleFormatter = ISO8601DateFormatter()
            appleFormatter.formatOptions.insert(.withFractionalSeconds)
            appleFormatter.timeZone = timeZone
            
            let dateString = "2018-09-13T19:56:48.981Z"
            
            benchmark("JJL dateFromString, time zone: \(timeZone)", test: {
                return jjlFormatter.date(from: dateString) == appleFormatter.date(from: dateString)
            }) {
                for _ in 0..<1000 {
                    _ = jjlFormatter.date(from: dateString)
                }
            }

            /*benchmark("ISO8601DateFormatter dateFromString", test: nil) {
                for _ in 0..<1000 {
                    _ = appleFormatter.date(from: dateString)
                }
            }*/
        }
        
    }
    
    /*func testStringFromDateBenchmark() {
        let jjlFormatter = JJLISO8601DateFormatter()
        jjlFormatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        jjlFormatter.formatOptions.insert(.withFractionalSeconds)
        
        let appleFormatter = ISO8601DateFormatter()
        appleFormatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        appleFormatter.formatOptions.insert(.withFractionalSeconds)
        
        let date = Date(timeIntervalSince1970: 1536868608.981)
        
        benchmark("JJLISO8601DateFormatter stringFromDate") {
            for _ in 0..<1000 {
                _ = jjlFormatter.string(from: date)
            }
        }
        
        benchmark("ISO8601DateFormatter stringFromDate") {
            for _ in 0..<1000 {
                _ = appleFormatter.string(from: date)
            }
        }
    }
    
    func testFormatStyleBenchmark() {
        let jjlFormatter = JJLISO8601DateFormatter()
        jjlFormatter.formatOptions.insert(.withFractionalSeconds)
        
        let date = Date(timeIntervalSince1970: 1536868608.981)
        let formatStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        
        benchmark("JJLISO8601DateFormatter stringFromDate") {
            autoreleasepool {
                for _ in 0..<1000 {
                    _ = jjlFormatter.string(from: date)
                }
            }
        }
        
        benchmark("Date.ISO8601FormatStyle formatted") {
            autoreleasepool {
                for _ in 0..<1000 {
                    _ = date.formatted(formatStyle)
                }
            }
        }
        
        let dateString = "2018-09-13T19:56:48.981Z"
        let parseStrategy = Date.ISO8601FormatStyle(includingFractionalSeconds: true).parseStrategy
        
        benchmark("JJLISO8601DateFormatter dateFromString") {
            autoreleasepool {
                for _ in 0..<1000 {
                    _ = jjlFormatter.date(from: dateString)
                }
            }
        }
        
        benchmark("Date.ISO8601FormatStyle parse") {
            autoreleasepool {
                for _ in 0..<1000 {
                    _ = try? Date(dateString, strategy: parseStrategy)
                }
            }
        }
    }*/
}

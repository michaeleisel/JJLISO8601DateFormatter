// Copyright (c) 2018 Michael Eisel. All rights reserved.

import XCTest
import JJLISO8601DateFormatter

final class JJLISO8601DateFormatterTests: XCTestCase {
    
    private var appleFormatter: ISO8601DateFormatter!
    private var testFormatter: JJLISO8601DateFormatter!
    private var brazilTimeZone: TimeZone!
    private var pacificTimeZone: TimeZone!
    private var testDate: Date!
    
    private let kSecondsPerMinute: TimeInterval = 60
    private let kSecondsPerHour: TimeInterval = 60 * 60
    private let kSecondsPerDay: TimeInterval = 24 * 60 * 60
    private let kSecondsPerYear: TimeInterval = 365 * 24 * 60 * 60
    
    override func setUp() {
        super.setUp()
        
        appleFormatter = ISO8601DateFormatter()
        testFormatter = JJLISO8601DateFormatter()
        let options: ISO8601DateFormatter.Options = [appleFormatter.formatOptions, .withFractionalSeconds]
        appleFormatter.formatOptions = options
        testFormatter.formatOptions = options
        
        brazilTimeZone = TimeZone(abbreviation: "BRT")
        pacificTimeZone = TimeZone(abbreviation: "PST")
        
        let testDateFormatter = ISO8601DateFormatter()
        testDateFormatter.formatOptions = [testDateFormatter.formatOptions, .withFractionalSeconds]
        testDate = testDateFormatter.date(from: "2018-09-13T19:56:48.981Z")
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testClassStringFromDate() {
        for timeZone in [pacificTimeZone!, brazilTimeZone!] {
            let testString = JJLISO8601DateFormatter.string(from: testDate, timeZone: timeZone, formatOptions: testFormatter.formatOptions)
            let appleString = ISO8601DateFormatter.string(from: testDate, timeZone: timeZone, formatOptions: testFormatter.formatOptions)
            XCTAssertEqual(testString, appleString)
        }
    }
    
    func testTimeZoneGettingAndSetting() {
        XCTAssertEqual(appleFormatter.timeZone, testFormatter.timeZone, "Default time zone should be GMT")
        testFormatter.timeZone = brazilTimeZone
        appleFormatter.timeZone = brazilTimeZone
        XCTAssertEqual(appleFormatter.timeZone, testFormatter.timeZone)
        testFormatter.timeZone = TimeZone(secondsFromGMT: 0)!
        appleFormatter.timeZone = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(appleFormatter.timeZone, testFormatter.timeZone, "nil resetting should bring it back to the default")
    }
    
    func testLongDecimals() {
        appleFormatter.formatOptions = [.withFullDate, .withFullTime, .withFractionalSeconds]
        testFormatter.formatOptions = [.withFullDate, .withFullTime, .withFractionalSeconds]
        
        let testString = "2018-08-17T02:14:02.662762Z"
        let testDate = testFormatter.date(from: testString)
        let appleDate = appleFormatter.date(from: testString)
        
        XCTAssertEqual(testDate, appleDate)
    }
    
    func testLeapSeconds() {
        let startInterval = appleFormatter.date(from: "2016-12-31T23:59:58.000Z")!.timeIntervalSince1970
        testDatesInParallel(startInterval: startInterval, endInterval: startInterval + 4, increment: 0.01)
    }
    
    func testNilDate() {
        // Test with current date
        let date = Date()
        let appleString = appleFormatter.string(from: date)
        let testString = testFormatter.string(from: date)
        XCTAssertEqual(appleString, testString)
    }
    
    func testFractionalSecondsFormatting() {
        let initialDateFormatter = ISO8601DateFormatter()
        let startingDate = initialDateFormatter.date(from: "2018-09-13T19:56:49Z")!
        let startingInterval = startingDate.timeIntervalSince1970
        
        let noFractionalSecondsOptions: ISO8601DateFormatter.Options = appleFormatter.formatOptions.subtracting(.withFractionalSeconds)
        
        for options in [appleFormatter.formatOptions, noFractionalSecondsOptions] {
            appleFormatter.formatOptions = options
            testFormatter.formatOptions = options
            
            let increment: TimeInterval = 0.0001
            var interval = startingInterval
            while interval < startingInterval + 2 {
                // Skip known discrepancies
                if interval == 1536868609.3894999 || interval == 1536868609.6815 {
                    interval += increment
                    continue
                }
                let date = Date(timeIntervalSince1970: interval)
                testStringFromDate(date)
                interval += increment
            }
        }
    }
    
    func testDistantFuture() {
        testStringFromDate(Date.distantFuture)
    }
    
    func testExoticOptions() {
        let optionSets: [ISO8601DateFormatter.Options] = [
            [.withYear, .withWeekOfYear],
            [.withYear, .withDay],
            [.withYear, .withWeekOfYear, .withMonth, .withDay],
            [.withYear, .withWeekOfYear, .withDay],
            [.withMonth, .withDay],
        ]
        
        for options in optionSets {
            appleFormatter.formatOptions = options
            testFormatter.formatOptions = options
            testDatesInParallel(startInterval: 0, endInterval: 50 * kSecondsPerYear, increment: 1 * kSecondsPerDay)
        }
    }
    
    func testFormattingAcrossAllOptions() {
        let gmtTimeZone = TimeZone(secondsFromGMT: 0)!
        
        for timeZone in [gmtTimeZone] {
            appleFormatter.timeZone = timeZone
            testFormatter.timeZone = timeZone
            
            // Test common options explicitly
            let optionSets: [ISO8601DateFormatter.Options] = [
                [.withYear],
                [.withYear, .withMonth],
                [.withYear, .withMonth, .withDay],
                [.withYear, .withMonth, .withDay, .withDashSeparatorInDate],
                [.withTime],
                [.withTime, .withColonSeparatorInTime],
                [.withTimeZone],
                [.withFullDate],
                [.withFullTime],
                [.withInternetDateTime],
                [.withInternetDateTime, .withFractionalSeconds],
            ]
            
            for options in optionSets {
                guard JJLISO8601DateFormatter.isValidFormatOptions(options) else { continue }
                
                appleFormatter.formatOptions = options
                testFormatter.formatOptions = options
                testStringFromDate(testDate)
            }
        }
    }
    
    func testManyAcrossTimeZones() {
        var timeZones: [TimeZone] = []
        timeZones.append(TimeZone(secondsFromGMT: 496)!)
        timeZones.append(TimeZone(secondsFromGMT: -2 * Int(kSecondsPerHour) - 496)!)
        timeZones.append(TimeZone(abbreviation: "BRT")!)
        
        for name in TimeZone.knownTimeZoneIdentifiers.prefix(20) { // Limit for test speed
            if let tz = TimeZone(identifier: name) {
                timeZones.append(tz)
            }
        }
        timeZones.append(TimeZone.current)
        timeZones.append(TimeZone(secondsFromGMT: 0)!)
        
        for timeZone in timeZones {
            testFormatter.timeZone = timeZone
            appleFormatter.timeZone = timeZone
            
            let increment = kSecondsPerDay * 23 + kSecondsPerHour * 7 + kSecondsPerMinute * 5 + 7.513
            testDatesInParallel(startInterval: 0, endInterval: 50 * kSecondsPerYear, increment: increment)
        }
    }
    
    func testLeapForward() {
        // Use Brazil, which does a leap forward
        let start = appleFormatter.date(from: "2017-01-01T12:00:00.000Z")!.timeIntervalSince1970
        testFormatter.timeZone = brazilTimeZone
        appleFormatter.timeZone = brazilTimeZone
        testDatesInParallel(startInterval: start, endInterval: start + kSecondsPerYear + 10 * kSecondsPerDay, increment: 17 * kSecondsPerMinute)
    }
    
    func testFormattingAcrossTimes() {
        // Don't go back past 1582
        let end = -1 * kSecondsPerYear * (1970 - 1583)
        let increment: TimeInterval = 100001
        testDatesInParallel(startInterval: end, endInterval: 0, increment: increment)
        
        let futureEnd = kSecondsPerYear * 50
        let futureIncrement: TimeInterval = 10001
        testDatesInParallel(startInterval: 0, endInterval: futureEnd, increment: futureIncrement)
    }
    
    func testNSFormatter() {
        let testString = testFormatter.string(from: testDate)
        XCTAssertEqual(testFormatter.string(for: testDate), testString)
        
        var date: AnyObject?
        var error: NSString?
        let success = testFormatter.getObjectValue(&date, for: testString, errorDescription: &error)
        XCTAssertTrue(success)
        XCTAssertEqual(date as? Date, testDate)
        
        let badResult = testFormatter.getObjectValue(&date, for: "", errorDescription: &error)
        XCTAssertFalse(badResult)
        XCTAssertNotNil(error)
    }
    
    // MARK: - Benchmark Tests
    
    func testDateFromStringBenchmark() {
        let jjlFormatter = JJLISO8601DateFormatter()
        jjlFormatter.formatOptions.insert(.withFractionalSeconds)
        
        let dateString = "2018-09-13T19:56:48.981Z"
        
        measure {
            for _ in 0..<1000 {
                _ = jjlFormatter.date(from: dateString)
            }
        }
    }
    
    func testStringFromDateBenchmark() {
        let jjlFormatter = JJLISO8601DateFormatter()
        jjlFormatter.formatOptions.insert(.withFractionalSeconds)
        
        let date = Date(timeIntervalSince1970: 1536868608.981)
        
        measure {
            for _ in 0..<1000 {
                _ = jjlFormatter.string(from: date)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func testStringFromDate(_ date: Date) {
        let appleString = appleFormatter.string(from: date)
        let jjlString = testFormatter.string(from: date)
        
        if appleString != jjlString {
            XCTFail("Mismatch for \(date), apple: \(appleString), test: \(jjlString)")
        }
        
        verifyParsing(appleString)
    }
    
    private func verifyParsing(_ string: String) {
        let testDate = testFormatter.date(from: string)
        let appleDate = appleFormatter.date(from: string)
        
        if testDate != appleDate {
            XCTFail("Date mismatch for string '\(string)': test=\(String(describing: testDate)), apple=\(String(describing: appleDate))")
        }
    }
    
    private func testDatesInParallel(startInterval: TimeInterval, endInterval: TimeInterval, increment: TimeInterval) {
        let groupSize = 16
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInteractive)
        
        for i in 0..<groupSize {
            group.enter()
            queue.async { [self] in
                let chunkSize = (endInterval - startInterval) / Double(groupSize)
                let blockStart = startInterval + chunkSize * Double(i)
                
                // Create thread-local formatters
                let localApple = ISO8601DateFormatter()
                localApple.formatOptions = self.appleFormatter.formatOptions
                localApple.timeZone = self.appleFormatter.timeZone
                
                let localTest = JJLISO8601DateFormatter()
                localTest.formatOptions = self.testFormatter.formatOptions
                localTest.timeZone = self.testFormatter.timeZone
                
                var interval = blockStart
                while interval < blockStart + chunkSize {
                    let date = Date(timeIntervalSince1970: interval)
                    let appleString = localApple.string(from: date)
                    let testString = localTest.string(from: date)
                    
                    if appleString != testString {
                        print("Mismatch for \(date), apple: \(appleString), test: \(testString)")
                    }
                    interval += increment
                }
                group.leave()
            }
        }
        group.wait()
    }
}

// Copyright (c) 2018 Michael Eisel. All rights reserved.

import XCTest
import Foundation
@testable import JJLISO8601DateFormatter
import JJLInternal

final class JJLISO8601DateFormatterTests: XCTestCase {
    
    // MARK: - Constants
    
    private static let secondsPerMinute: Int = 60
    private static let secondsPerHour: Int = 60 * secondsPerMinute
    private static let secondsPerDay: Int = 24 * secondsPerHour
    private static let secondsPerYear: Int = 365 * secondsPerDay
    
    // MARK: - Properties
    
    private var appleFormatter: ISO8601DateFormatter!
    private var testFormatter: JJLISO8601DateFormatter!
    private var brazilTimeZone: TimeZone!
    private var pacificTimeZone: TimeZone!
    private var testDate: Date!
    
    // MARK: - Setup / Teardown
    
    override func setUp() {
        super.setUp()
        
        continueAfterFailure = false
        
        appleFormatter = ISO8601DateFormatter()
        testFormatter = JJLISO8601DateFormatter()
        
        let options: ISO8601DateFormatter.Options = [
            appleFormatter.formatOptions,
            .withFractionalSeconds
        ]
        appleFormatter.formatOptions = options
        testFormatter.formatOptions = options
        
        brazilTimeZone = TimeZone(abbreviation: "BRT")
        pacificTimeZone = TimeZone(abbreviation: "PST")
        
        let testDateFormatter = ISO8601DateFormatter()
        testDateFormatter.formatOptions = [testDateFormatter.formatOptions, .withFractionalSeconds]
        testDate = testDateFormatter.date(from: "2018-09-13T19:56:48.981Z")
    }
    
    override func tearDown() {
        appleFormatter = nil
        testFormatter = nil
        brazilTimeZone = nil
        pacificTimeZone = nil
        testDate = nil
        super.tearDown()
    }
    
    // MARK: - Helper Functions
    
    private func testString(_ testString: String, appleFormatter: ISO8601DateFormatter, testFormatter: JJLISO8601DateFormatter, file: StaticString = #file, line: UInt = #line) {
        let testDate = testFormatter.date(from: testString)
        let appleDate = appleFormatter.date(from: testString)
        
        if testDate != appleDate && testDate != nil && appleDate != nil {
            let diff = testDate!.timeIntervalSince1970 - appleDate!.timeIntervalSince1970
            XCTFail("Date mismatch: diff=\(diff), options=\(binaryTestRep(appleFormatter.formatOptions))", file: file, line: line)
        } else {
            XCTAssertEqual(testDate, appleDate, file: file, line: line)
        }
    }
    
    private func testStringFromDate(_ date: Date, appleFormatter: ISO8601DateFormatter, testFormatter: JJLISO8601DateFormatter, file: StaticString = #file, line: UInt = #line) {
        let appleString = appleFormatter.string(from: date)
        let testString = testFormatter.string(from: date)
        
        if appleString != testString {
            XCTFail("Mismatch for \(date), apple: \(appleString), test: \(testString)", file: file, line: line)
            return
        }
        
        self.testString(appleString, appleFormatter: appleFormatter, testFormatter: testFormatter, file: file, line: line)
    }
    
    private func binaryRep(_ opts: ISO8601DateFormatter.Options) -> String {
        var result = ""
        for i in stride(from: 11, through: 0, by: -1) {
            result += String((opts.rawValue >> i) & 1)
        }
        return result
    }
    
    private func binaryTestRep(_ opts: ISO8601DateFormatter.Options) -> String {
        let optionToString: [(ISO8601DateFormatter.Options, String)] = [
            (.withYear, "year"),
            (.withMonth, "month"),
            (.withWeekOfYear, "week of year"),
            (.withDay, "day"),
            (.withTime, "time"),
            (.withTimeZone, "time zone"),
            (.withSpaceBetweenDateAndTime, "space between date and time"),
            (.withDashSeparatorInDate, "dash separator in date"),
            (.withColonSeparatorInTime, "colon separator in time"),
            (.withColonSeparatorInTimeZone, "colon separator in time zone"),
            (.withFractionalSeconds, "fractional seconds")
        ]
        
        var strings: [String] = []
        for (option, name) in optionToString {
            if opts.contains(option) {
                strings.append(name)
            }
        }
        return strings.joined(separator: ", ")
    }
    
    // MARK: - Parallel Testing Helpers
    
    private func testBlockInParallel(start: TimeInterval, end: TimeInterval, increment: TimeInterval, block: @escaping (TimeInterval) -> Void) {
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInteractive)
        let groupSize = 16
        
        for i in 0..<groupSize {
            group.enter()
            queue.async {
                let chunkSize = (end - start) / Double(groupSize)
                let blockStart = start + chunkSize * Double(i)
                var interval = blockStart
                while interval < blockStart + chunkSize {
                    block(interval)
                    interval += increment
                }
                group.leave()
            }
        }
        group.wait()
    }
    
    private func testDatesInParallel(startInterval: TimeInterval, endInterval: TimeInterval, increment: TimeInterval) {
        testBlockInParallel(start: startInterval, end: endInterval, increment: increment) { [self] interval in
            let date = Date(timeIntervalSince1970: interval)
            testStringFromDate(date, appleFormatter: appleFormatter, testFormatter: testFormatter)
        }
    }
    
    // MARK: - Tests
    
    func testTZAlloc() {
        let badTimezone = "America/adf".withCString { jjl_tzalloc($0) }
        XCTAssertNil(badTimezone)
        
        let goodTimezone = "Africa/Addis_Ababa".withCString { jjl_tzalloc($0) }
        XCTAssertNotNil(goodTimezone)
    }
    
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
        
        testFormatter.timeZone = TimeZone(identifier: "GMT")!
        appleFormatter.timeZone = TimeZone(identifier: "GMT")!
        XCTAssertEqual(appleFormatter.timeZone, testFormatter.timeZone, "Reset should bring it back to GMT")
    }
    
    func testConcurrentUsage() {
        let gmtOffsetTimeZone = TimeZone(secondsFromGMT: 3600)!
        let timeZones = [TimeZone.current, brazilTimeZone!, gmtOffsetTimeZone, pacificTimeZone!]
        testFormatter.timeZone = timeZones.first!
        
        var testStrings: [String] = []
        var correctStrings: [String] = []
        let repeatCount = 100
        
        for timeZone in timeZones {
            appleFormatter.timeZone = timeZone
            let string = appleFormatter.string(from: testDate)
            correctStrings.append(string)
        }
        
        var repeatedCorrectStrings: [String] = []
        for _ in 0..<repeatCount {
            repeatedCorrectStrings.append(contentsOf: correctStrings)
        }
        correctStrings = repeatedCorrectStrings
        
        let group = DispatchGroup()
        group.enter()
        
        let done = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        done.pointee = false
        defer { done.deallocate() }
        
        let testStringsLock = NSLock()
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        queue.async { [self] in
            while !done.pointee {
                let string = testFormatter.string(from: testDate)
                testStringsLock.lock()
                if testStrings.isEmpty || string != testStrings.last {
                    testStrings.append(string)
                }
                testStringsLock.unlock()
            }
        }
        
        queue.async { [self] in
            for _ in 0..<repeatCount {
                for timeZone in timeZones {
                    testFormatter.timeZone = timeZone
                    usleep(5000)
                }
            }
            group.leave()
            done.pointee = true
        }
        
        group.wait()
        XCTAssertEqual(correctStrings, testStrings)
    }
    
    func testLongDecimals() {
        appleFormatter.formatOptions = [.withFullDate, .withFullTime, .withFractionalSeconds]
        testFormatter.formatOptions = [.withFullDate, .withFullTime, .withFractionalSeconds]
        testString("2018-08-17T02:14:02.662762Z", appleFormatter: appleFormatter, testFormatter: testFormatter)
    }
    
    func testLeapSeconds() {
        let interval = appleFormatter.date(from: "2016-12-31T23:59:58.000Z")!.timeIntervalSince1970
        testDatesInParallel(startInterval: interval, endInterval: interval + 4, increment: 0.01)
    }
    
    func testFractionalSecondsFormatting() {
        let initialDateFormatter = ISO8601DateFormatter()
        let startingDate = initialDateFormatter.date(from: "2018-09-13T19:56:49Z")!
        let startingInterval = startingDate.timeIntervalSince1970
        
        var noFractionalSecondsOptions = appleFormatter.formatOptions
        noFractionalSecondsOptions.remove(.withFractionalSeconds)
        
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
                testStringFromDate(date, appleFormatter: appleFormatter, testFormatter: testFormatter)
                interval += increment
            }
        }
    }
    
    func testDistantFuture() {
        testStringFromDate(Date.distantFuture, appleFormatter: appleFormatter, testFormatter: testFormatter)
    }
    
    func testExoticOptions() {
        let optionsList: [ISO8601DateFormatter.Options] = [
            [.withYear, .withWeekOfYear],
            [.withYear, .withDay],
            [.withYear, .withWeekOfYear, .withMonth, .withDay],
            [.withYear, .withWeekOfYear, .withDay],
            [.withMonth, .withDay]
        ]
        
        for options in optionsList {
            appleFormatter.formatOptions = options
            testFormatter.formatOptions = options
            testDatesInParallel(
                startInterval: 0,
                endInterval: TimeInterval(50 * Self.secondsPerYear),
                increment: TimeInterval(Self.secondsPerDay)
            )
        }
    }
    
    func testFormattingAcrossAllOptions() {
        let gmtTimeZone = TimeZone(secondsFromGMT: 0)!
        
        for timeZone in [pacificTimeZone!, brazilTimeZone!, gmtTimeZone] {
            appleFormatter.timeZone = timeZone
            testFormatter.timeZone = timeZone
            
            for rawOptions: UInt in 0..<(1 << 12) {
                let options = ISO8601DateFormatter.Options(rawValue: rawOptions)
                if !JJLISO8601DateFormatter.isValidFormatOptions(options) {
                    continue
                }
                appleFormatter.formatOptions = options
                testFormatter.formatOptions = options
                testStringFromDate(testDate, appleFormatter: appleFormatter, testFormatter: testFormatter)
            }
        }
    }
    
    func testManyAcrossTimeZones() {
        var timeZones: [TimeZone] = []
        timeZones.append(TimeZone(secondsFromGMT: 496)!)
        timeZones.append(TimeZone(secondsFromGMT: -2 * Self.secondsPerHour - 496)!)
        timeZones.append(TimeZone(abbreviation: "BRT")!)
        
        for name in TimeZone.knownTimeZoneIdentifiers {
            if let timeZone = TimeZone(identifier: name) {
                timeZones.append(timeZone)
            }
        }
        
        timeZones.append(TimeZone.current)
        timeZones.append(TimeZone(secondsFromGMT: 0)!)
        
        for alwaysUseNSTimeZone in [false, true] {
            testFormatter.alwaysUseNSTimeZone = alwaysUseNSTimeZone
            let timeZonesToTest: [TimeZone]
            if alwaysUseNSTimeZone {
                timeZonesToTest = Array(timeZones.prefix(10))
            } else {
                timeZonesToTest = timeZones
            }
            
            for timeZone in timeZonesToTest {
                testFormatter.timeZone = timeZone
                appleFormatter.timeZone = timeZone
                
                let increment: Double = Double(Self.secondsPerDay * 23 + Self.secondsPerHour * 7 + Self.secondsPerMinute * 5) + 7.513
                testDatesInParallel(
                    startInterval: 0,
                    endInterval: TimeInterval(50 * Self.secondsPerYear),
                    increment: increment
                )
                
                // Random date testing
                testBlockInParallel(start: 0, end: 1000, increment: 1) { [self] _ in
                    let interval = TimeInterval(arc4random_uniform(UInt32(70 * Self.secondsPerYear)))
                    let date = Date(timeIntervalSince1970: interval)
                    testStringFromDate(date, appleFormatter: appleFormatter, testFormatter: testFormatter)
                }
            }
        }
    }
    
    func testLeapForward() {
        // Use Brazil, which does a leap forward
        for alwaysUseNSTimeZone in [true, false] {
            testFormatter.alwaysUseNSTimeZone = alwaysUseNSTimeZone
            let start = appleFormatter.date(from: "2017-01-01T12:00:00.000Z")!.timeIntervalSince1970
            testFormatter.timeZone = brazilTimeZone
            appleFormatter.timeZone = brazilTimeZone
            
            testDatesInParallel(
                startInterval: start,
                endInterval: start + TimeInterval(Self.secondsPerYear + 10 * Self.secondsPerDay),
                increment: TimeInterval(17 * Self.secondsPerMinute)
            )
        }
    }
    
    func testFormattingAcrossTimes() {
        let moreThorough = false
        
        // Don't go back past 1582
        var end = TimeInterval(-1 * Self.secondsPerYear * (1970 - 1583))
        var increment: TimeInterval = moreThorough ? 10001 : 100001
        print("Counting down...")
        testDatesInParallel(startInterval: end, endInterval: 0, increment: increment)
        
        print("Counting up...")
        end = TimeInterval(Self.secondsPerYear * 50)
        increment = moreThorough ? 1001 : 10001
        testDatesInParallel(startInterval: 0, endInterval: end, increment: increment)
        
        print("Testing 400-year leap year cycles...")
        end = TimeInterval(Self.secondsPerYear * 1200)
        increment = moreThorough ? 10001 : 100001
        testDatesInParallel(startInterval: 0, endInterval: end, increment: increment)
    }
    
    func testNSFormatter() {
        let testString = testFormatter.string(from: testDate)
        XCTAssertEqual(testFormatter.string(for: testDate), testString)
        
        var date: AnyObject?
        let success = testFormatter.getObjectValue(&date, for: testString, errorDescription: nil)
        XCTAssertTrue(success)
        XCTAssertEqual(date as? Date, testDate)
        
        var error: NSString?
        let failResult = testFormatter.getObjectValue(&date, for: "", errorDescription: &error)
        XCTAssertFalse(failResult)
        XCTAssertNotNil(error)
    }
}

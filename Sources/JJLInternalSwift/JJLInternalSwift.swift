// Copyright (c) 2018 Michael Eisel. All rights reserved.
// Pure Swift implementation of JJLInternal

import Foundation

// MARK: - Constants

public let kJJLMaxDateLength: Int32 = 50

private let kItoaStringsLength = 3000
private let kItoaEachStringLength = 4

// MARK: - Format Options (matching CFISO8601DateFormatOptions)

public struct JJLFormatOptions: OptionSet, Sendable {
    public let rawValue: UInt
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    public static let withYear = JJLFormatOptions(rawValue: 1 << 0)
    public static let withMonth = JJLFormatOptions(rawValue: 1 << 1)
    public static let withWeekOfYear = JJLFormatOptions(rawValue: 1 << 2)
    public static let withDay = JJLFormatOptions(rawValue: 1 << 3)
    public static let withTime = JJLFormatOptions(rawValue: 1 << 4)
    public static let withTimeZone = JJLFormatOptions(rawValue: 1 << 5)
    public static let withSpaceBetweenDateAndTime = JJLFormatOptions(rawValue: 1 << 6)
    public static let withDashSeparatorInDate = JJLFormatOptions(rawValue: 1 << 7)
    public static let withColonSeparatorInTime = JJLFormatOptions(rawValue: 1 << 8)
    public static let withColonSeparatorInTimeZone = JJLFormatOptions(rawValue: 1 << 9)
    public static let withFractionalSeconds = JJLFormatOptions(rawValue: 1 << 10)
    
    public static let withFullDate: JJLFormatOptions = [.withYear, .withMonth, .withDay, .withDashSeparatorInDate]
    public static let withFullTime: JJLFormatOptions = [.withTime, .withTimeZone, .withColonSeparatorInTime, .withColonSeparatorInTimeZone]
    public static let withInternetDateTime: JJLFormatOptions = [.withFullDate, .withFullTime]
}

// MARK: - Time Components (replaces struct tm)

public struct JJLTimeComponents {
    public var year: Int32 = 0      // years since 1900
    public var month: Int32 = 0     // months since January (0-11)
    public var day: Int32 = 0       // day of month (1-31)
    public var hour: Int32 = 0      // hours since midnight (0-23)
    public var minute: Int32 = 0    // minutes after hour (0-59)
    public var second: Int32 = 0    // seconds after minute (0-60 for leap second)
    public var weekday: Int32 = 0   // days since Sunday (0-6)
    public var yearDay: Int32 = 0   // days since January 1 (0-365)
    public var gmtOffset: Int32 = 0 // seconds east of UTC
    
    public init() {}
}

// MARK: - Date Formatter Buffer (using UInt8 array for speed)

public struct JJLDateBuffer {
    private var bytes: [UInt8]
    private var position: Int = 0
    
    public init() {
        bytes = [UInt8](repeating: 0, count: Int(kJJLMaxDateLength))
    }
    
    @inline(__always)
    public mutating func append(_ char: UInt8) {
        bytes[position] = char
        position += 1
    }
    
    @inline(__always)
    public mutating func append(_ chars: UnsafeBufferPointer<UInt8>) {
        for i in 0..<chars.count {
            bytes[position + i] = chars[i]
        }
        position += chars.count
    }
    
    @inline(__always)
    public mutating func appendASCII(_ char: Character) {
        bytes[position] = char.asciiValue!
        position += 1
    }
    
    public mutating func clear() {
        position = 0
    }
    
    public func toString() -> String {
        return String(decoding: bytes[0..<position], as: UTF8.self)
    }
}

// MARK: - Precomputed Integer-to-String Lookup Table (using bytes)

private struct ItoaTable {
    // Each entry is 4 bytes like [0x30, 0x30, 0x30, 0x30] for "0000"
    private var table: [UInt8]  // Flat array: index * 4 gives start
    
    init() {
        table = [UInt8](repeating: 0x30, count: kItoaStringsLength * kItoaEachStringLength)  // Fill with '0'
        
        for i in 0..<kItoaStringsLength {
            var num = i
            var digit = kItoaEachStringLength - 1
            while num > 0 {
                table[i * kItoaEachStringLength + digit] = UInt8(0x30 + num % 10)
                num /= 10
                digit -= 1
            }
        }
    }
    
    @inline(__always)
    func appendNumber(_ num: Int32, digits: Int, to buffer: inout JJLDateBuffer) {
        if num >= 0 && num < Int32(kItoaStringsLength) {
            let start = Int(num) * kItoaEachStringLength + (kItoaEachStringLength - digits)
            for i in 0..<digits {
                buffer.append(table[start + i])
            }
        } else {
            // Slow path for large numbers
            var temp = [UInt8](repeating: 0x30, count: digits)
            var n = num
            var idx = digits - 1
            while n > 0 && idx >= 0 {
                temp[idx] = UInt8(0x30 + n % 10)
                n /= 10
                idx -= 1
            }
            for byte in temp {
                buffer.append(byte)
            }
        }
    }
}

private let itoaTable = ItoaTable()

// MARK: - Timezone Wrapper

public final class JJLTimeZone: @unchecked Sendable {
    public let timeZone: TimeZone
    private let calendar: Calendar
    
    public init?(name: String) {
        guard let tz = TimeZone(identifier: name) else {
            return nil
        }
        self.timeZone = tz
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        self.calendar = cal
    }
    
    public func components(from date: Date) -> JJLTimeComponents {
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: date)
        
        var tc = JJLTimeComponents()
        let year = comps.year ?? 1970
        let month = comps.month ?? 1
        let day = comps.day ?? 1
        
        tc.year = Int32(year - 1900)
        tc.month = Int32(month - 1)
        tc.day = Int32(day)
        tc.hour = Int32(comps.hour ?? 0)
        tc.minute = Int32(comps.minute ?? 0)
        tc.second = Int32(comps.second ?? 0)
        tc.weekday = Int32((comps.weekday ?? 1) - 1) // Convert 1-7 to 0-6
        
        // Calculate day of year manually
        tc.yearDay = Self.dayOfYear(year: Int32(year), month: Int32(month), day: Int32(day))
        tc.gmtOffset = Int32(timeZone.secondsFromGMT(for: date))
        
        return tc
    }
    
    private static func dayOfYear(year: Int32, month: Int32, day: Int32) -> Int32 {
        let isLeap = ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0)
        let daysBeforeMonth: [Int32] = isLeap
            ? [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]
            : [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        return daysBeforeMonth[Int(month) - 1] + day - 1
    }
    
    public func date(from components: inout JJLTimeComponents) -> Date? {
        var dateComponents = DateComponents()
        dateComponents.year = Int(components.year) + 1900
        dateComponents.month = Int(components.month) + 1
        dateComponents.day = Int(components.day)
        dateComponents.hour = Int(components.hour)
        dateComponents.minute = Int(components.minute)
        dateComponents.second = Int(components.second)
        
        return calendar.date(from: dateComponents)
    }
}

// MARK: - Private Global State

private var gmtTimeZone: JJLTimeZone?
private let initLock = NSLock()
private var isInitialized = false

// MARK: - Public API

public func jjlPerformInitialSetup() {
    initLock.lock()
    defer { initLock.unlock() }
    
    guard !isInitialized else { return }
    gmtTimeZone = JJLTimeZone(name: "GMT")
    isInitialized = true
}

public func jjlAllocTimeZone(_ name: String) -> JJLTimeZone? {
    return JJLTimeZone(name: name)
}

// MARK: - Helper Functions

@inline(__always)
private func daysInYear(_ year: Int32) -> Int32 {
    let isLeap = (year % 400 == 0) || (year % 4 == 0 && year % 100 != 0)
    return isLeap ? 366 : 365
}

@inline(__always)
private func isLeapYear(_ year: Int32) -> Bool {
    return ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0)
}

@inline(__always)
private func startingDayOfWeekForYear(_ y: Int32) -> Int32 {
    // Sakamoto's method
    var year = y
    let t: [Int32] = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
    year -= 1
    let sakamotoResult = (year + year/4 - year/100 + year/400 + t[0] + 1) % 7
    return (sakamotoResult - 1 + 7) % 7
}

// MARK: - Date Formatting

public func jjlFillBuffer(
    buffer: inout JJLDateBuffer,
    timeInSeconds: Double,
    options: JJLFormatOptions,
    timeZone: JJLTimeZone?,
    fallbackOffset: Double
) {
    // Empty options check (power of 2 means only 1 bit set or empty)
    let rawOpts = options.rawValue
    if (rawOpts & (rawOpts - 1)) == 0 {
        return
    }
    
    let showFractionalSeconds = options.contains(.withFractionalSeconds)
    
    var adjustedTime = timeInSeconds
    var fractionalComponent = timeInSeconds.truncatingRemainder(dividingBy: 1.0)
    if fractionalComponent < 0 {
        fractionalComponent += 1.0
    }
    
    // Handle rounding - if fractional component rounds to 1000ms, round up the whole time
    // and reset fractional to 0
    if fractionalComponent >= 0.9995 {
        adjustedTime = adjustedTime.rounded()
        fractionalComponent = 0
    }
    
    let effectiveOffset = timeZone != nil ? 0 : fallbackOffset
    let dateWithOffset = Date(timeIntervalSince1970: adjustedTime + effectiveOffset)
    
    var components: JJLTimeComponents
    if let tz = timeZone {
        components = tz.components(from: dateWithOffset)
    } else {
        components = gmtTimeZone?.components(from: dateWithOffset) ?? JJLTimeComponents()
    }
    components.gmtOffset += Int32(fallbackOffset)
    
    let showYear = options.contains(.withYear)
    let showDateSeparator = options.contains(.withDashSeparatorInDate)
    let showMonth = options.contains(.withMonth)
    let showDay = options.contains(.withDay)
    let isInternetDateTime = options.isSuperset(of: .withInternetDateTime)
    let showWeekOfYear = !isInternetDateTime && options.contains(.withWeekOfYear)
    let showDate = showYear || showMonth || showDay || showWeekOfYear
    
    let daysAfterFirstWeekday = (components.weekday - 1 + 7) % 7
    let year = components.year + 1900
    let usePreviousYear = showWeekOfYear && daysAfterFirstWeekday - components.yearDay > 7 - 4
    let useNextYear = showWeekOfYear && components.yearDay - daysAfterFirstWeekday + 7 - daysInYear(year) >= 4
    
    if showYear {
        var yearToShow = year
        if usePreviousYear {
            yearToShow -= 1
        } else if useNextYear {
            yearToShow += 1
        }
        itoaTable.appendNumber(yearToShow, digits: 4, to: &buffer)
    }
    
    if showMonth {
        if showDateSeparator && showYear {
            buffer.append(0x2D)  // '-'
        }
        itoaTable.appendNumber(components.month + 1, digits: 2, to: &buffer)
    }
    
    if showWeekOfYear {
        if showDateSeparator && (showYear || showMonth) {
            buffer.append(0x2D)  // '-'
        }
        buffer.append(0x57)  // 'W'
        
        var week: Int32 = 0
        if useNextYear {
            week = 0
        } else {
            var daysToDivide = components.yearDay - daysAfterFirstWeekday
            if usePreviousYear {
                daysToDivide += daysInYear(year - 1)
            }
            week = daysToDivide / 7
            if daysToDivide % 7 >= 4 {
                week += 1
            }
        }
        itoaTable.appendNumber(week + 1, digits: 2, to: &buffer)
    }
    
    if showDay {
        if showDateSeparator && (showYear || showMonth || showWeekOfYear) {
            buffer.append(0x2D)  // '-'
        }
        if showWeekOfYear {
            itoaTable.appendNumber(daysAfterFirstWeekday + 1, digits: 2, to: &buffer)
        } else if showMonth {
            itoaTable.appendNumber(components.day, digits: 2, to: &buffer)
        } else {
            itoaTable.appendNumber(components.yearDay + 1, digits: 3, to: &buffer)
        }
    }
    
    let showTime = options.contains(.withTime)
    let showTimeSeparator = options.contains(.withColonSeparatorInTime)
    let timeSeparatorIsSpace = options.contains(.withSpaceBetweenDateAndTime)
    
    if showTime {
        if showDate {
            buffer.append(timeSeparatorIsSpace ? 0x20 : 0x54)  // ' ' or 'T'
        }
        itoaTable.appendNumber(components.hour, digits: 2, to: &buffer)
        if showTimeSeparator {
            buffer.append(0x3A)  // ':'
        }
        itoaTable.appendNumber(components.minute, digits: 2, to: &buffer)
        if showTimeSeparator {
            buffer.append(0x3A)  // ':'
        }
        itoaTable.appendNumber(components.second, digits: 2, to: &buffer)
        
        if showFractionalSeconds {
            buffer.append(0x2E)  // '.'
            
            // Use pre-computed fractional component
            var millis = Int32((fractionalComponent * 1000).rounded())
            if millis == 1000 { millis = 999 }
            itoaTable.appendNumber(millis, digits: 3, to: &buffer)
        }
    }
    
    if options.contains(.withTimeZone) {
        var offset = components.gmtOffset
        if offset == 0 {
            buffer.append(0x5A)  // 'Z'
        } else {
            let sign: UInt8
            if offset < 0 {
                offset = -offset
                sign = 0x2D  // '-'
            } else {
                sign = 0x2B  // '+'
            }
            
            let showColonSeparatorInTimeZone = options.contains(.withColonSeparatorInTimeZone)
            let hours = offset / (60 * 60)
            let minutes = (offset % (60 * 60)) / 60
            let seconds = offset % 60
            
            buffer.append(sign)
            itoaTable.appendNumber(hours, digits: 2, to: &buffer)
            if showColonSeparatorInTimeZone {
                buffer.append(0x3A)  // ':'
            }
            itoaTable.appendNumber(minutes, digits: 2, to: &buffer)
            
            if seconds > 0 {
                if showColonSeparatorInTimeZone {
                    buffer.append(0x3A)  // ':'
                }
                itoaTable.appendNumber(seconds, digits: 2, to: &buffer)
            }
        }
    }
}

// MARK: - UTF8 Iterator Parser (using .utf8 iterator directly)

private struct JJLUTF8Parser {
    private var iterator: String.UTF8View.Iterator
    private var current: UInt8?
    private var hasPeeked: Bool = false
    var errorOccurred: Bool = false
    
    init(_ utf8: String.UTF8View) {
        self.iterator = utf8.makeIterator()
    }
    
    @inline(__always)
    var isAtEnd: Bool {
        mutating get {
            if !hasPeeked {
                current = iterator.next()
                hasPeeked = true
            }
            return current == nil
        }
    }
    
    @inline(__always)
    mutating func peek() -> UInt8? {
        if !hasPeeked {
            current = iterator.next()
            hasPeeked = true
        }
        return current
    }
    
    @inline(__always)
    mutating func advance() {
        if hasPeeked {
            hasPeeked = false
            current = nil
        } else {
            _ = iterator.next()
        }
    }
    
    @inline(__always)
    mutating func consumeNumber(maxLength: Int32) -> Int32 {
        var length: Int32 = 0
        var isNegative = false
        
        if let c = peek(), c == 0x2D {  // '-'
            isNegative = true
            advance()
        }
        
        var result: Int32 = 0
        while !isAtEnd && (maxLength == -1 || length < maxLength) {
            guard let c = peek(), c >= 0x30 && c <= 0x39 else { break }  // '0'-'9'
            result = result * 10 + Int32(c - 0x30)
            length += 1
            advance()
        }
        
        if length == 0 {
            errorOccurred = true
            return 0
        }
        
        return isNegative ? -result : result
    }
    
    @inline(__always)
    mutating func consumeCharacter(_ expected: UInt8) {
        guard let c = peek(), c == expected else {
            errorOccurred = true
            return
        }
        advance()
    }
    
    @inline(__always)
    mutating func consumeSeparator() {
        guard let c = peek() else {
            errorOccurred = true
            return
        }
        if c != 0x20 && c != 0x2D && c != 0x3A {  // ' ', '-', ':'
            errorOccurred = true
            return
        }
        advance()
    }
    
    @inline(__always)
    mutating func consumeFractionalSeconds() -> Int32 {
        guard let c = peek() else {
            errorOccurred = true
            return 0
        }
        
        if c == 0x2E || c == 0x2C {  // '.' or ','
            advance()
        } else {
            errorOccurred = true
            return 0
        }
        
        var num: Int32 = 0
        var length: Int32 = 0
        
        // Read up to 3 significant digits
        while !isAtEnd && length < 3 {
            guard let c = peek(), c >= 0x30 && c <= 0x39 else { break }
            num = num * 10 + Int32(c - 0x30)
            length += 1
            advance()
        }
        
        // Consume any leftover decimal digits
        while !isAtEnd {
            guard let c = peek(), c >= 0x30 && c <= 0x39 else { break }
            advance()
        }
        
        if length == 0 {
            return 0
        } else if length == 1 {
            return num * 100
        } else if length == 2 {
            return num * 10
        } else {
            return num
        }
    }
    
    @inline(__always)
    mutating func consumeTimeZone(separator: Bool) -> Int32 {
        guard let c = peek() else {
            errorOccurred = true
            return 0
        }
        
        if c == 0x5A {  // 'Z'
            advance()
            return 0
        }
        
        let isNegative = c == 0x2D  // '-'
        advance()
        
        let hours = consumeNumber(maxLength: 2)
        if separator {
            consumeCharacter(0x3A)  // ':'
        }
        let minutes = consumeNumber(maxLength: 2)
        
        var seconds: Int32 = 0
        if !isAtEnd {
            if separator {
                if let c = peek(), c == 0x3A {  // ':'
                    consumeCharacter(0x3A)
                    seconds = consumeNumber(maxLength: 2)
                }
            } else if let c = peek(), c >= 0x30 && c <= 0x39 {
                seconds = consumeNumber(maxLength: 2)
            }
        }
        
        let absValue = hours * 60 * 60 + minutes * 60 + seconds
        return isNegative ? -absValue : absValue
    }
}

// MARK: - Fast mktime (direct calculation for UTC/offset cases)

@inline(__always)
private func fastMktime(year: Int32, month: Int32, day: Int32, hour: Int32, minute: Int32, second: Int32) -> Int64 {
    let daysBeforeMonth: [Int32] = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
    
    let y = year - 1970
    
    var days: Int64 = Int64(y) * 365
    
    if y > 0 {
        days += Int64((y + 1) / 4)
        days -= Int64((y + 69) / 100)
        days += Int64((y + 369) / 400)
    } else if y < 0 {
        days += Int64((y - 2) / 4)
        days -= Int64((y - 30) / 100)
        days += Int64((y - 30) / 400)
    }
    
    days += Int64(daysBeforeMonth[Int(month)])
    
    if month > 1 && isLeapYear(year) {
        days += 1
    }
    
    days += Int64(day - 1)
    
    return days * 86400 + Int64(hour) * 3600 + Int64(minute) * 60 + Int64(second)
}

// MARK: - Date Parsing

public func jjlTimeIntervalForString(
    _ string: String,
    options: JJLFormatOptions,
    timeZone: JJLTimeZone?
) -> (interval: Double, success: Bool) {
    let rawOpts = options.rawValue
    if (rawOpts & (rawOpts - 1)) == 0 {
        return (0, false)
    }
    
    // Use .utf8 iterator directly
    var parser = JJLUTF8Parser(string.utf8)
    return parseWithIterator(&parser, options: options, timeZone: timeZone)
}

@inline(__always)
private func parseWithIterator(
    _ parser: inout JJLUTF8Parser,
    options: JJLFormatOptions,
    timeZone: JJLTimeZone?
) -> (interval: Double, success: Bool) {
    var components = JJLTimeComponents()
    
    let showFractionalSeconds = options.contains(.withFractionalSeconds)
    let showYear = options.contains(.withYear)
    let showDateSeparator = options.contains(.withDashSeparatorInDate)
    let showMonth = options.contains(.withMonth)
    let showDay = options.contains(.withDay)
    let showTime = options.contains(.withTime)
    let showTimeSeparator = options.contains(.withColonSeparatorInTime)
    let timeSeparatorIsSpace = options.contains(.withSpaceBetweenDateAndTime)
    let showTimeZone = options.contains(.withTimeZone)
    let isInternetDateTime = options.isSuperset(of: .withInternetDateTime)
    let showColonSeparatorInTimeZone = options.contains(.withColonSeparatorInTimeZone)
    let showWeekOfYear = !isInternetDateTime && options.contains(.withWeekOfYear)
    let showDate = showYear || showMonth || showDay || showWeekOfYear
    
    var dayOffset: Int32 = 1
    let year: Int32 = showYear ? parser.consumeNumber(maxLength: 4) : 2000
    
    let firstMonday = (7 - startingDayOfWeekForYear(year)) % 7
    if showWeekOfYear {
        dayOffset += firstMonday < 4 ? firstMonday : firstMonday - 7
    }
    components.year = year - 1900
    
    if showMonth {
        if showDateSeparator && showYear {
            parser.consumeSeparator()
        }
        let month = parser.consumeNumber(maxLength: 2) - 1
        if !showWeekOfYear {
            components.month = month
        }
    }
    
    if showWeekOfYear {
        if showDateSeparator && (showYear || showMonth) {
            parser.consumeSeparator()
        }
        parser.consumeCharacter(0x57)  // 'W'
        let weeks = parser.consumeNumber(maxLength: 2) - 1
        dayOffset += weeks * 7
    }
    
    if showDay {
        if showDateSeparator && (showYear || showMonth || showWeekOfYear) {
            parser.consumeSeparator()
        }
        dayOffset += parser.consumeNumber(maxLength: -1)
        dayOffset -= 1
    }
    
    if showMonth {
        components.day = dayOffset
    } else {
        let febDays: Int32 = isLeapYear(year) ? 29 : 28
        let daysInMonth: [Int32] = [31, febDays, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 365]
        var month: Int32 = 0
        var remainingDays = dayOffset
        
        while month < 12 {
            let monthDays = daysInMonth[Int(month)]
            if remainingDays <= monthDays {
                break
            }
            remainingDays -= monthDays
            month += 1
        }
        
        if month == 12 {
            components.month = 0
            components.year += 1
        } else {
            components.month = month
        }
        components.day = remainingDays
    }
    
    var millis: Int32 = 0
    if showTime {
        if showDate {
            let separator: UInt8 = timeSeparatorIsSpace ? 0x20 : 0x54  // ' ' or 'T'
            parser.consumeCharacter(separator)
        }
        components.hour = parser.consumeNumber(maxLength: 2)
        if showTimeSeparator {
            parser.consumeSeparator()
        }
        components.minute = parser.consumeNumber(maxLength: 2)
        if showTimeSeparator {
            parser.consumeSeparator()
        }
        components.second = parser.consumeNumber(maxLength: 2)
        if showFractionalSeconds {
            millis = parser.consumeFractionalSeconds()
        }
    }
    
    if showTimeZone {
        let tzOffset = parser.consumeTimeZone(separator: showColonSeparatorInTimeZone)
        
        if parser.errorOccurred {
            return (0, false)
        }
        
        // Fast path: direct calculation
        let timestamp = fastMktime(
            year: components.year + 1900,
            month: components.month,
            day: components.day,
            hour: components.hour,
            minute: components.minute,
            second: components.second
        )
        
        let result = Double(timestamp - Int64(tzOffset)) + Double(millis) / 1000.0
        return (result, true)
    }
    
    if parser.errorOccurred {
        return (0, false)
    }
    
    // Slow path: use Calendar
    guard let tz = timeZone, let date = tz.date(from: &components) else {
        return (0, false)
    }
    
    return (date.timeIntervalSince1970 + Double(millis) / 1000.0, true)
}

// MARK: - Convenience function for C-style buffer output

public func jjlStringFromDate(
    timeInSeconds: Double,
    options: JJLFormatOptions,
    timeZone: JJLTimeZone?,
    fallbackOffset: Double
) -> String {
    var buffer = JJLDateBuffer()
    jjlFillBuffer(
        buffer: &buffer,
        timeInSeconds: timeInSeconds,
        options: options,
        timeZone: timeZone,
        fallbackOffset: fallbackOffset
    )
    return buffer.toString()
}

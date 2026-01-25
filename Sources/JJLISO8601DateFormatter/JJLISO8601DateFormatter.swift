// Copyright (c) 2018 Michael Eisel. All rights reserved.
// Swift wrapper for JJLISO8601DateFormatter

import Foundation
import JJLInternalSwift

/// A high-performance ISO 8601 date formatter implemented in pure Swift.
public final class JJLISO8601DateFormatter: Formatter {

    private static let gmtTimeZone = TimeZone(identifier: "GMT")!
    private static var nameToTimeZone: [String: JJLTimeZone] = [:]
    private static var dictionaryLock = pthread_rwlock_t()

    private var jjlTimeZone: JJLTimeZone?
    private var timeZoneVarsLock = pthread_rwlock_t()
    private var fallbackFormatter: ISO8601DateFormatter?
    private var _formatOptions: ISO8601DateFormatter.Options
    private var _timeZone: TimeZone
    var alwaysUseNSTimeZone: Bool = false

    public var timeZone: TimeZone {
        get {
            return _timeZone
        }
        set {
            pthread_rwlock_wrlock(&timeZoneVarsLock)
            defer { pthread_rwlock_unlock(&timeZoneVarsLock) }

            _timeZone = newValue
            jjlTimeZone = Self.jjlTimeZone(for: _timeZone, alwaysUseNSTimeZone: alwaysUseNSTimeZone)

            if jjlTimeZone == nil {
                fallbackFormatter = ISO8601DateFormatter()
                fallbackFormatter?.formatOptions = _formatOptions
                fallbackFormatter?.timeZone = _timeZone
            } else {
                fallbackFormatter = nil
            }
        }
    }

    public var formatOptions: ISO8601DateFormatter.Options {
        get {
            return _formatOptions
        }
        set {
            assert(Self.isValidFormatOptions(newValue), "Invalid format options. Must be empty or only contain valid options: [.withYear, .withMonth, .withWeekOfYear, .withDay, .withTime, .withTimeZone, .withSpaceBetweenDateAndTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withColonSeparatorInTimeZone, .withFractionalSeconds, .withFullDate, .withFullTime, .withInternetDateTime]")

            pthread_rwlock_wrlock(&timeZoneVarsLock)
            defer { pthread_rwlock_unlock(&timeZoneVarsLock) }

            _formatOptions = newValue
            fallbackFormatter?.formatOptions = newValue
        }
    }

    // MARK: - Initialization

    /// Creates a formatter object set to the GMT time zone and preconfigured with the RFC 3339 standard format ("yyyy-MM-dd'T'HH:mm:ssXXXXX").
    ///
    /// The default format options are: [
    ///     .withInternetDateTime,
    ///     .withDashSeparatorInDate,
    ///     .withColonSeparatorInTime,
    ///     .withColonSeparatorInTimeZone
    /// ]
    public override init() {
        Self.performInitialSetupIfNecessary()

        pthread_rwlock_init(&timeZoneVarsLock, nil)

        _formatOptions = [
            .withInternetDateTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
            .withColonSeparatorInTimeZone
        ]
        _timeZone = Self.gmtTimeZone

        super.init()

        jjlTimeZone = Self.jjlTimeZone(for: _timeZone, alwaysUseNSTimeZone: alwaysUseNSTimeZone)
    }

    deinit {
        pthread_rwlock_destroy(&timeZoneVarsLock)
    }

    public required init?(coder: NSCoder) {
        Self.performInitialSetupIfNecessary()

        pthread_rwlock_init(&timeZoneVarsLock, nil)

        _formatOptions = ISO8601DateFormatter.Options(rawValue: UInt(coder.decodeInteger(forKey: "formatOptions")))
        _timeZone = coder.decodeObject(forKey: "timeZone") as? TimeZone ?? Self.gmtTimeZone
        alwaysUseNSTimeZone = coder.decodeBool(forKey: "alwaysUseNSTimeZone")
        jjlTimeZone = Self.jjlTimeZone(for: _timeZone, alwaysUseNSTimeZone: alwaysUseNSTimeZone)

        super.init(coder: coder)

        if jjlTimeZone == nil {
            fallbackFormatter = ISO8601DateFormatter()
            fallbackFormatter?.formatOptions = _formatOptions
            fallbackFormatter?.timeZone = _timeZone
        }
    }


    public override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(Int(_formatOptions.rawValue), forKey: "formatOptions")
        coder.encode(_timeZone, forKey: "timeZone")
        coder.encode(alwaysUseNSTimeZone, forKey: "alwaysUseNSTimeZone")
    }

    // MARK: - Static Setup

    /// Thread-safe one-time initialization using Swift's lazy static semantics
    private static let setupOnce: Void = {
        pthread_rwlock_init(&dictionaryLock, nil)
        jjlPerformInitialSetup()
    }()

    private static func performInitialSetupIfNecessary() {
        _ = setupOnce
    }

    // MARK: - Time Zone Handling

    /// Adjusts time zone name for GMT offset formats (e.g., "GMT+0800" -> "GMT+08:00")
    /// Note: For pure Swift implementation, we don't flip the sign as Foundation handles this correctly
    private static func adjustedTimeZoneName(_ name: String) -> String {
        let pattern = "^GMT(\\+|-)(\\d{2})(\\d{2})$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: name, options: [], range: NSRange(name.startIndex..., in: name)) else {
            return name
        }

        let signRange = Range(match.range(at: 1), in: name)!
        let hoursRange = Range(match.range(at: 2), in: name)!
        let minutesRange = Range(match.range(at: 3), in: name)!

        let sign = name[signRange]
        let hours = name[hoursRange]
        let minutes = name[minutesRange]

        return "GMT\(sign)\(hours):\(minutes)"
    }

    /// Gets or creates a JJLTimeZone for the given TimeZone (uses global cache)
    private static func jjlTimeZone(for timeZone: TimeZone, alwaysUseNSTimeZone: Bool) -> JJLTimeZone? {
        if alwaysUseNSTimeZone {
            return nil
        }

        let name = adjustedTimeZoneName(timeZone.identifier)

        // Check global cache first (read lock)
        pthread_rwlock_rdlock(&dictionaryLock)
        if let cached = nameToTimeZone[name] {
            pthread_rwlock_unlock(&dictionaryLock)
            return cached
        }
        pthread_rwlock_unlock(&dictionaryLock)

        // Create new timezone
        let jjlTz = jjlAllocTimeZone(name)

        if jjlTz == nil {
            print("[JJLISO8601DateFormatter] Warning: time zone not found for name \(name), falling back to NSTimeZone. Performance will be degraded")
        } else {
            // Store in global cache (write lock)
            pthread_rwlock_wrlock(&dictionaryLock)
            nameToTimeZone[name] = jjlTz
            pthread_rwlock_unlock(&dictionaryLock)
        }

        return jjlTz
    }

    // MARK: - Format Validation

    /// Validates the provided format options.
    public static func isValidFormatOptions(_ formatOptions: ISO8601DateFormatter.Options) -> Bool {
        var mask: ISO8601DateFormatter.Options = [
            .withYear, .withMonth, .withWeekOfYear, .withDay,
            .withTime, .withTimeZone, .withSpaceBetweenDateAndTime,
            .withDashSeparatorInDate, .withColonSeparatorInTime,
            .withColonSeparatorInTimeZone, .withFullDate, .withFullTime,
            .withInternetDateTime
        ]

        if #available(iOS 11.0, macOS 10.13, tvOS 11.0, visionOS 1.0, watchOS 4.0, *) {
            mask.insert(.withFractionalSeconds)
        }

        return formatOptions.isEmpty || formatOptions.isSubset(of: mask)
    }
    
    // MARK: - Options Conversion
    
    @inline(__always)
    private static func jjlOptions(from options: ISO8601DateFormatter.Options) -> JJLFormatOptions {
        var result = JJLFormatOptions()
        
        if options.contains(.withYear) { result.insert(.withYear) }
        if options.contains(.withMonth) { result.insert(.withMonth) }
        if options.contains(.withWeekOfYear) { result.insert(.withWeekOfYear) }
        if options.contains(.withDay) { result.insert(.withDay) }
        if options.contains(.withTime) { result.insert(.withTime) }
        if options.contains(.withTimeZone) { result.insert(.withTimeZone) }
        if options.contains(.withSpaceBetweenDateAndTime) { result.insert(.withSpaceBetweenDateAndTime) }
        if options.contains(.withDashSeparatorInDate) { result.insert(.withDashSeparatorInDate) }
        if options.contains(.withColonSeparatorInTime) { result.insert(.withColonSeparatorInTime) }
        if options.contains(.withColonSeparatorInTimeZone) { result.insert(.withColonSeparatorInTimeZone) }
        if #available(iOS 11.0, macOS 10.13, tvOS 11.0, visionOS 1.0, watchOS 4.0, *) {
            if options.contains(.withFractionalSeconds) { result.insert(.withFractionalSeconds) }
        }
        
        return result
    }

    // MARK: - Date Formatting

    /// Returns a string representation of the specified date.
    public func string(from date: Date) -> String {
        pthread_rwlock_rdlock(&timeZoneVarsLock)
        defer { pthread_rwlock_unlock(&timeZoneVarsLock) }

        return Self.stringFromDate(date, formatOptions: _formatOptions, jjlTimeZone: jjlTimeZone, timeZone: _timeZone)
    }

    /// Returns a date from the specified string, or nil if parsing fails.
    public func date(from string: String) -> Date? {
        guard !string.isEmpty, !_formatOptions.isEmpty else {
            return nil
        }

        pthread_rwlock_rdlock(&timeZoneVarsLock)
        defer { pthread_rwlock_unlock(&timeZoneVarsLock) }

        guard let jjlTz = jjlTimeZone else {
            return fallbackFormatter?.date(from: string)
        }

        let result = jjlTimeIntervalForString(
            string,
            options: Self.jjlOptions(from: _formatOptions),
            timeZone: jjlTz
        )

        return result.success ? Date(timeIntervalSince1970: result.interval) : nil
    }

    /// Returns a string representation of the specified date using the provided time zone and format options.
    public static func string(from date: Date, timeZone: TimeZone, formatOptions: ISO8601DateFormatter.Options) -> String {
        performInitialSetupIfNecessary()
        let jjlTz = Self.jjlTimeZone(for: timeZone, alwaysUseNSTimeZone: false)
        return stringFromDate(date, formatOptions: formatOptions, jjlTimeZone: jjlTz, timeZone: timeZone)
    }

    @inline(__always)
    private static func stringFromDate(
        _ date: Date,
        formatOptions: ISO8601DateFormatter.Options,
        jjlTimeZone: JJLTimeZone?,
        timeZone: TimeZone
    ) -> String {
        let time = date.timeIntervalSince1970
        let offset: Double = jjlTimeZone != nil ? 0 : Double(timeZone.secondsFromGMT(for: date))

        return jjlStringFromDate(
            timeInSeconds: time,
            options: jjlOptions(from: formatOptions),
            timeZone: jjlTimeZone,
            fallbackOffset: offset
        )
    }

    // MARK: - NSFormatter Override

    public override func string(for obj: Any?) -> String? {
        guard let date = obj as? Date else {
            return nil
        }
        return string(from: date)
    }

    public override func getObjectValue(
        _ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
        for string: String,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        guard let parsedDate = date(from: string) else {
            obj?.pointee = nil
            error?.pointee = "Malformed date string"
            return false
        }

        obj?.pointee = parsedDate as NSDate
        error?.pointee = nil
        return true
    }
}

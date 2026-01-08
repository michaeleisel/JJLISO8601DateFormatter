// Copyright (c) 2018 Michael Eisel. All rights reserved.
// Swift wrapper for JJLISO8601DateFormatter

import Foundation
import JJLInternal

/// A high-performance ISO 8601 date formatter that uses C for date processing.
/// Note that this class is not thread-safe.
public final class JJLISO8601DateFormatter: Formatter {
    
    private static let gmtTimeZone = TimeZone(identifier: "GMT")!
    private static var nameToTimeZone: [String: timezone_t] = [:]
    private static var dictionaryLock = pthread_rwlock_t()
    
    private var cTimeZone: timezone_t?
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
            cTimeZone = Self.cTimeZone(for: _timeZone, alwaysUseNSTimeZone: alwaysUseNSTimeZone)
            
            if cTimeZone == nil {
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
        
        cTimeZone = Self.cTimeZone(for: _timeZone, alwaysUseNSTimeZone: alwaysUseNSTimeZone)
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
        cTimeZone = Self.cTimeZone(for: _timeZone, alwaysUseNSTimeZone: alwaysUseNSTimeZone)
        
        super.init(coder: coder)
        
        if cTimeZone == nil {
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
        JJLPerformInitialSetup()
    }()
    
    private static func performInitialSetupIfNecessary() {
        _ = setupOnce
    }
    
    // MARK: - Time Zone Handling
    
    /// Adjusts time zone name for GMT offset formats (e.g., "GMT+0800" -> "GMT-08:00")
    private static func adjustedTimeZoneName(_ name: String) -> String {
        let pattern = "^GMT(\\+|-)(\\d{2})(\\d{2})$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: name, options: [], range: NSRange(name.startIndex..., in: name)) else {
            return name
        }
        
        let signRange = Range(match.range(at: 1), in: name)!
        let hoursRange = Range(match.range(at: 2), in: name)!
        let minutesRange = Range(match.range(at: 3), in: name)!
        
        let origSign = name[signRange]
        let sign: Character = origSign == "-" ? "+" : "-"
        let hours = name[hoursRange]
        let minutes = name[minutesRange]
        
        return "GMT\(sign)\(hours):\(minutes)"
    }
    
    /// Gets or creates a C timezone for the given TimeZone (uses global cache)
    private static func cTimeZone(for timeZone: TimeZone, alwaysUseNSTimeZone: Bool) -> timezone_t? {
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
        let cTimeZone = name.utf8CString.withUnsafeBufferPointer { jjl_tzalloc($0.baseAddress) }
        
        if cTimeZone == nil {
            print("[JJLISO8601DateFormatter] Warning: time zone not found for name \(name), falling back to NSTimeZone. Performance will be degraded")
        } else {
            // Store in global cache (write lock)
            pthread_rwlock_wrlock(&dictionaryLock)
            nameToTimeZone[name] = cTimeZone
            pthread_rwlock_unlock(&dictionaryLock)
        }
        
        return cTimeZone
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
    
    // MARK: - Date Formatting
    
    /// Returns a string representation of the specified date.
    public func string(from date: Date) -> String {
        pthread_rwlock_rdlock(&timeZoneVarsLock)
        defer { pthread_rwlock_unlock(&timeZoneVarsLock) }
        
        return Self.stringFromDate(date, formatOptions: _formatOptions, cTimeZone: cTimeZone, timeZone: _timeZone)
    }
    
    /// Returns a date from the specified string, or nil if parsing fails.
    public func date(from string: String) -> Date? {
        guard !string.isEmpty, !_formatOptions.isEmpty else {
            return nil
        }
        
        pthread_rwlock_rdlock(&timeZoneVarsLock)
        defer { pthread_rwlock_unlock(&timeZoneVarsLock) }
        
        guard let cTimeZone = cTimeZone else {
            return fallbackFormatter?.date(from: string)
        }
        
        var errorOccurred = false
        let cString = string.utf8CString
        let interval = cString.withUnsafeBufferPointer { buffer -> TimeInterval in
            return JJLTimeIntervalForString(
                buffer.baseAddress,
                Int32(strlen(buffer.baseAddress!)),
                CFISO8601DateFormatOptions(rawValue: UInt(_formatOptions.rawValue)),
                cTimeZone,
                &errorOccurred
            )
        }
        
        return errorOccurred ? nil : Date(timeIntervalSince1970: interval)
    }
    
    /// Returns a string representation of the specified date using the provided time zone and format options.
    public static func string(from date: Date, timeZone: TimeZone, formatOptions: ISO8601DateFormatter.Options) -> String {
        performInitialSetupIfNecessary()
        let cTimeZone = Self.cTimeZone(for: timeZone, alwaysUseNSTimeZone: false)
        return stringFromDate(date, formatOptions: formatOptions, cTimeZone: cTimeZone, timeZone: timeZone)
    }
    
    @inline(__always)
    private static func stringFromDate(
        _ date: Date,
        formatOptions: ISO8601DateFormatter.Options,
        cTimeZone: timezone_t?,
        timeZone: TimeZone
    ) -> String {
        let time = date.timeIntervalSince1970
        let offset: Double = cTimeZone != nil ? 0 : Double(timeZone.secondsFromGMT(for: date))

        return withUnsafeTemporaryAllocation(of: CChar.self, capacity: Int(kJJLMaxDateLength)) { buffer in
            buffer.initialize(repeating: 0)
            
            JJLFillBufferForDate(
                buffer.baseAddress,
                time,
                CFISO8601DateFormatOptions(rawValue: UInt(formatOptions.rawValue)),
                cTimeZone,
                offset
            )
            
            return String(cString: buffer.baseAddress!)
        }
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

// Copyright (c) 2018 Michael Eisel. All rights reserved.
// C++20 rewrite with Objective-C wrapper

#import "include/JJLISO8601DateFormatter.h"
#import "JJLDateFormatter.hpp"
#import <Foundation/Foundation.h>
#import <mutex>

// Convert between NSISO8601DateFormatOptions and jjl::FormatOptions
static jjl::FormatOptions convertOptions(NSISO8601DateFormatOptions nsOptions) {
    uint32_t result = 0;
    
    if (nsOptions & NSISO8601DateFormatWithYear)
        result |= static_cast<uint32_t>(jjl::FormatOptions::Year);
    if (nsOptions & NSISO8601DateFormatWithMonth)
        result |= static_cast<uint32_t>(jjl::FormatOptions::Month);
    if (nsOptions & NSISO8601DateFormatWithWeekOfYear)
        result |= static_cast<uint32_t>(jjl::FormatOptions::WeekOfYear);
    if (nsOptions & NSISO8601DateFormatWithDay)
        result |= static_cast<uint32_t>(jjl::FormatOptions::Day);
    if (nsOptions & NSISO8601DateFormatWithTime)
        result |= static_cast<uint32_t>(jjl::FormatOptions::Time);
    if (nsOptions & NSISO8601DateFormatWithTimeZone)
        result |= static_cast<uint32_t>(jjl::FormatOptions::TimeZone);
    if (nsOptions & NSISO8601DateFormatWithSpaceBetweenDateAndTime)
        result |= static_cast<uint32_t>(jjl::FormatOptions::SpaceBetweenDateAndTime);
    if (nsOptions & NSISO8601DateFormatWithDashSeparatorInDate)
        result |= static_cast<uint32_t>(jjl::FormatOptions::DashSeparatorInDate);
    if (nsOptions & NSISO8601DateFormatWithColonSeparatorInTime)
        result |= static_cast<uint32_t>(jjl::FormatOptions::ColonSeparatorInTime);
    if (nsOptions & NSISO8601DateFormatWithColonSeparatorInTimeZone)
        result |= static_cast<uint32_t>(jjl::FormatOptions::ColonSeparatorInTimeZone);
    if (@available(iOS 11.0, macOS 10.13, *)) {
        if (nsOptions & NSISO8601DateFormatWithFractionalSeconds)
            result |= static_cast<uint32_t>(jjl::FormatOptions::FractionalSeconds);
    }
    
    return static_cast<jjl::FormatOptions>(result);
}

static NSTimeZone *sGMTTimeZone = nil;

@implementation JJLISO8601DateFormatter {
    NSTimeZone *_timeZone;
    NSISO8601DateFormatOptions _formatOptions;
    std::mutex _mutex;
}

+ (void)initialize {
    if (self == [JJLISO8601DateFormatter class]) {
        sGMTTimeZone = [NSTimeZone timeZoneWithName:@"GMT"];
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _formatOptions = NSISO8601DateFormatWithInternetDateTime | 
                         NSISO8601DateFormatWithDashSeparatorInDate | 
                         NSISO8601DateFormatWithColonSeparatorInTime | 
                         NSISO8601DateFormatWithColonSeparatorInTimeZone;
        _timeZone = sGMTTimeZone;
    }
    return self;
}

- (void)dealloc {
    // mutex destructor handles cleanup
}

#pragma mark - Properties

- (NSISO8601DateFormatOptions)formatOptions {
    std::lock_guard<std::mutex> lock(_mutex);
    return _formatOptions;
}

- (void)setFormatOptions:(NSISO8601DateFormatOptions)formatOptions {
    NSAssert(JJLIsValidFormatOptions(formatOptions), 
             @"Invalid format options");
    std::lock_guard<std::mutex> lock(_mutex);
    _formatOptions = formatOptions;
}

- (NSTimeZone *)timeZone {
    std::lock_guard<std::mutex> lock(_mutex);
    return _timeZone;
}

- (void)setTimeZone:(NSTimeZone *)timeZone {
    std::lock_guard<std::mutex> lock(_mutex);
    _timeZone = timeZone ?: sGMTTimeZone;
}

#pragma mark - Formatting

- (NSString *)stringFromDate:(NSDate *)date {
    if (!date) {
        return nil;
    }
    
    NSISO8601DateFormatOptions opts;
    NSTimeZone *tz;
    {
        std::lock_guard<std::mutex> lock(_mutex);
        opts = _formatOptions;
        tz = _timeZone;
    }
    
    // Get timezone offset for this date
    NSInteger tzOffset = [tz secondsFromGMTForDate:date];
    
    // Apple's NSISO8601DateFormatter rounds timezone offsets to whole minutes
    // ONLY for fixed-offset timezones (those with names like "GMT+XXXX").
    // IANA timezone names preserve sub-minute offsets.
    NSInteger finalOffset = tzOffset;
    NSString *tzName = tz.name;
    if ([tzName hasPrefix:@"GMT"] || [tzName hasPrefix:@"UTC"]) {
        // Round to nearest minute (matches Apple's behavior)
        // For positive: 496s = 8.27min -> 8min; 30s = 0.5min -> 1min
        // For negative: -496s = -8.27min -> -8min; -30s = -0.5min -> -1min
        NSInteger sign = tzOffset >= 0 ? 1 : -1;
        NSInteger absOffset = labs(tzOffset);
        NSInteger minutes = (absOffset + 30) / 60; // Round to nearest minute
        finalOffset = sign * minutes * 60;
    }
    
    // Convert NSDate to TimePoint
    NSTimeInterval interval = [date timeIntervalSince1970];
    
    // Handle fractional seconds properly for negative timestamps
    double integralPart;
    double fractionalPart = modf(interval, &integralPart);
    
    int64_t millis;
    if (fractionalPart >= 0) {
        millis = static_cast<int64_t>(integralPart) * 1000 + 
                 static_cast<int64_t>(std::round(fractionalPart * 1000.0));
    } else {
        // For negative times, fractional part is also negative
        millis = static_cast<int64_t>(std::round(interval * 1000.0));
    }
    
    auto tp = jjl::TimePoint(std::chrono::milliseconds(millis));
    
    std::string result = jjl::ISO8601DateFormatter::format(
        tp, 
        convertOptions(opts), 
        static_cast<int32_t>(finalOffset)
    );
    
    return [NSString stringWithUTF8String:result.c_str()];
}

- (nullable NSDate *)dateFromString:(NSString *)string {
    if (!string || string.length == 0) {
        return nil;
    }
    
    NSISO8601DateFormatOptions opts;
    NSTimeZone *tz;
    {
        std::lock_guard<std::mutex> lock(_mutex);
        opts = _formatOptions;
        tz = _timeZone;
        if (opts == 0) return nil;
    }
    
    std::string_view str([string UTF8String], [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    jjl::FormatOptions jjlOpts = convertOptions(opts);
    
    // Check if the format includes timezone - if so, we don't need special handling
    bool hasTimezone = (opts & NSISO8601DateFormatWithTimeZone) != 0;
    
    if (hasTimezone) {
        // Timezone is in the string, parse directly with no default offset
        auto result = jjl::ISO8601DateFormatter::parse(str, jjlOpts, 0);
        if (!result) return nil;
        
        auto millis = result->time_since_epoch().count();
        return [NSDate dateWithTimeIntervalSince1970:static_cast<double>(millis) / 1000.0];
    }
    
    // No timezone in format - we need to apply the formatter's timezone
    // First, parse as if it's UTC to get a reference date
    auto firstPass = jjl::ISO8601DateFormatter::parse(str, jjlOpts, 0);
    if (!firstPass) return nil;
    
    // Get the preliminary date (interpreted as UTC)
    auto millis = firstPass->time_since_epoch().count();
    NSDate *preliminaryDate = [NSDate dateWithTimeIntervalSince1970:static_cast<double>(millis) / 1000.0];
    
    // Get the timezone offset for this date
    NSInteger tzOffset = [tz secondsFromGMTForDate:preliminaryDate];
    
    // Now parse again with the correct offset
    auto result = jjl::ISO8601DateFormatter::parse(str, jjlOpts, static_cast<int32_t>(tzOffset));
    if (!result) return nil;
    
    millis = result->time_since_epoch().count();
    return [NSDate dateWithTimeIntervalSince1970:static_cast<double>(millis) / 1000.0];
}

#pragma mark - Class Methods

+ (NSString *)stringFromDate:(NSDate *)date 
                    timeZone:(NSTimeZone *)timeZone 
               formatOptions:(NSISO8601DateFormatOptions)formatOptions {
    if (!date) {
        return nil;
    }
    
    NSInteger tzOffset = [timeZone secondsFromGMTForDate:date];
    NSTimeInterval interval = [date timeIntervalSince1970];
    auto millis = static_cast<int64_t>(std::round(interval * 1000.0));
    auto tp = jjl::TimePoint(std::chrono::milliseconds(millis));
    
    std::string result = jjl::ISO8601DateFormatter::format(
        tp, 
        convertOptions(formatOptions), 
        static_cast<int32_t>(tzOffset)
    );
    
    return [NSString stringWithUTF8String:result.c_str()];
}

#pragma mark - NSFormatter Methods

- (BOOL)getObjectValue:(out id _Nullable *)obj 
             forString:(NSString *)string 
      errorDescription:(out NSString * _Nullable *)error {
    if (!obj) {
        return NO;
    }
    
    *obj = [self dateFromString:string];
    BOOL success = (*obj != nil);
    
    if (error) {
        *error = success ? nil : @"Malformed date string";
    }
    
    return success;
}

- (NSString *)stringForObjectValue:(id)obj {
    if (![obj isKindOfClass:[NSDate class]]) {
        return nil;
    }
    return [self stringFromDate:(NSDate *)obj];
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    std::lock_guard<std::mutex> lock(_mutex);
    [coder encodeInteger:static_cast<NSInteger>(_formatOptions) forKey:@"formatOptions"];
    [coder encodeObject:_timeZone forKey:@"timeZone"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [self init];
    if (self) {
        _formatOptions = static_cast<NSISO8601DateFormatOptions>([coder decodeIntegerForKey:@"formatOptions"]);
        _timeZone = [coder decodeObjectOfClass:[NSTimeZone class] forKey:@"timeZone"];
        if (!_timeZone) {
            _timeZone = sGMTTimeZone;
        }
    }
    return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end

#pragma mark - C Functions

BOOL JJLIsValidFormatOptions(NSISO8601DateFormatOptions formatOptions) {
    NSISO8601DateFormatOptions mask = 
        NSISO8601DateFormatWithYear | 
        NSISO8601DateFormatWithMonth | 
        NSISO8601DateFormatWithWeekOfYear | 
        NSISO8601DateFormatWithDay | 
        NSISO8601DateFormatWithTime | 
        NSISO8601DateFormatWithTimeZone | 
        NSISO8601DateFormatWithSpaceBetweenDateAndTime | 
        NSISO8601DateFormatWithDashSeparatorInDate | 
        NSISO8601DateFormatWithColonSeparatorInTime | 
        NSISO8601DateFormatWithColonSeparatorInTimeZone | 
        NSISO8601DateFormatWithFullDate | 
        NSISO8601DateFormatWithFullTime | 
        NSISO8601DateFormatWithInternetDateTime;
    
    if (@available(iOS 11.0, macOS 10.13, *)) {
        mask |= NSISO8601DateFormatWithFractionalSeconds;
    }
    
    return formatOptions == 0 || !(formatOptions & ~mask);
}

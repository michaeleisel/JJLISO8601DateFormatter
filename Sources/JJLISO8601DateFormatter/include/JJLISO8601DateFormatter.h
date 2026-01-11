// Copyright (c) 2018 Michael Eisel. All rights reserved.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A high-performance, thread-safe ISO 8601 date formatter.
///
/// This class provides a drop-in replacement for NSISO8601DateFormatter with
/// significantly better performance. It uses C++20's std::chrono for the
/// underlying date/time calculations.
///
/// Note that this class is thread-safe for all operations.
@interface JJLISO8601DateFormatter : NSFormatter <NSCoding, NSSecureCoding>

/// The time zone used for formatting and parsing. Defaults to GMT.
/// Setting to nil resets to GMT.
@property (null_resettable, copy) NSTimeZone *timeZone;

/// The format options used when formatting and parsing dates.
@property NSISO8601DateFormatOptions formatOptions;

/// Creates a formatter with the default RFC 3339 format.
///
/// The default format is: "yyyy-MM-dd'T'HH:mm:ssXXXXX"
/// Using options: NSISO8601DateFormatWithInternetDateTime |
///                NSISO8601DateFormatWithDashSeparatorInDate |
///                NSISO8601DateFormatWithColonSeparatorInTime |
///                NSISO8601DateFormatWithColonSeparatorInTimeZone
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/// Formats a date as an ISO 8601 string.
/// @param date The date to format.
/// @return The formatted string, or nil if the date is nil.
- (nullable NSString *)stringFromDate:(nullable NSDate *)date;

/// Parses an ISO 8601 string into a date.
/// @param string The string to parse.
/// @return The parsed date, or nil if parsing fails.
- (nullable NSDate *)dateFromString:(NSString *)string;

/// Convenience method for one-off formatting.
/// @param date The date to format.
/// @param timeZone The time zone to use.
/// @param formatOptions The format options to use.
/// @return The formatted string.
+ (NSString *)stringFromDate:(NSDate *)date 
                    timeZone:(NSTimeZone *)timeZone 
               formatOptions:(NSISO8601DateFormatOptions)formatOptions;

@end

/// Validates that the given format options are valid.
/// @param formatOptions The options to validate.
/// @return YES if the options are valid, NO otherwise.
FOUNDATION_EXPORT BOOL JJLIsValidFormatOptions(NSISO8601DateFormatOptions formatOptions);

NS_ASSUME_NONNULL_END

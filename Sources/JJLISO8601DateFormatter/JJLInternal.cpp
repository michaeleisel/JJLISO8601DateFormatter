//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import "Vendor/tzdb/tzfile__.h"
#import <time.h>
#import <assert.h>
#import <string.h>
#import <CoreFoundation/CFDateFormatter.h>
#import <pthread.h>
#import <math.h>
#import <stdio.h>
#import <stdlib.h>
#import <limits.h>
#import <dispatch/dispatch.h>

#import "JJLInternal.h"

#include <chrono>

using namespace std::chrono;

static bool sIsIOS11OrHigher = false;
static timezone_t sGMTTimeZone = NULL;

static const int32_t kJJLItoaStringsLength = 3000;
static const int32_t kJJLItoaEachStringLength = 4;

static char sItoaStrings[kJJLItoaStringsLength][kJJLItoaEachStringLength];

#define unlikely(x) __builtin_expect(!!(x), 0)

extern "C" void JJLPerformInitialSetup() {
    if (__builtin_available(iOS 11.0, *)) {
        sIsIOS11OrHigher = true;
    } else {
        sIsIOS11OrHigher = false;
    }

    memset(sItoaStrings, '0', sizeof(sItoaStrings));
    for (int32_t i = 0; i < kJJLItoaStringsLength; i++) {
        int32_t num = i;
        int32_t digit = kJJLItoaEachStringLength - 1;
        while (num > 0) {
            sItoaStrings[i][digit] = '0' + num % 10;
            num /= 10;
            digit--;
        }
    }
    sGMTTimeZone = jjl_tzalloc("GMT");
}

static inline void JJLPushBuffer(char **string, char *newBuffer, int32_t size) {
    memcpy(*string, newBuffer, size);
    *string += size;
}

static inline void JJLPushNumber(char **string, int32_t num, int32_t fixedDigitLength) {
    if (0 <= num && num < kJJLItoaStringsLength) {
        JJLPushBuffer(string, &(sItoaStrings[num][kJJLItoaEachStringLength - fixedDigitLength]), fixedDigitLength);
    } else {
        // Slow path, but will practically never be needed
        char str[16];  // Fixed size buffer
        snprintf(str, sizeof(str), "%04d", num);
        JJLPushBuffer(string, str, (int32_t)strlen(str));
    }
}

static inline void JJLFillBufferWithFractionalSeconds(double time, char **string) {
    double unused = 0;
    double fractionalComponent = modf(time, &unused);
    // Handle negative fractional component for dates before 1970
    if (fractionalComponent < 0) {
        fractionalComponent += 1.0;
    }
    int32_t millis = (int32_t)lround(fractionalComponent * 1000);
    if (millis == 1000) millis = 999; // Avoid overflow from rounding
    JJLPushNumber(string, millis, 3);
}

// Use std::chrono for leap year check
static inline bool JJLIsLeapYear(int32_t y) {
    return year{y}.is_leap();
}

static inline int32_t JJLDaysInYear(int32_t y) {
    return JJLIsLeapYear(y) ? 366 : 365;
}

static bool JJLGetShowFractionalSeconds(CFISO8601DateFormatOptions options)
{
    if (sIsIOS11OrHigher) {
        return !!(options & kCFISO8601DateFormatWithFractionalSeconds);
    } else {
        return false;
    }
}

// Compute weekday using std::chrono (returns 0=Sunday, 1=Monday, ..., 6=Saturday)
static inline int32_t JJLWeekdayForDate(int32_t y, int32_t m, int32_t d) {
    year_month_day ymd{year{y}, month{static_cast<unsigned>(m)}, day{static_cast<unsigned>(d)}};
    weekday wd{sys_days{ymd}};
    return static_cast<int32_t>(wd.c_encoding()); // 0=Sunday, 1=Monday, etc.
}

// Get the Monday-based weekday for Jan 1 of a given year (0=Monday, 6=Sunday)
static inline int32_t JJLStartingDayOfWeekForYear(int32_t y) {
    int32_t sundayBased = JJLWeekdayForDate(y, 1, 1);
    // Shift from Sunday-based (0=Sun) to Monday-based (0=Mon)
    return (sundayBased - 1 + 7) % 7;
}

extern "C" void JJLFillBufferForDate(char *buffer, double timeInSeconds, CFISO8601DateFormatOptions options, timezone_t timeZone, double fallbackOffset) {
    if ((options & (options - 1)) == 0) {
        return;
    }
    struct tm components = {0};

    bool showFractionalSeconds = JJLGetShowFractionalSeconds(options);

    double unused = 0;
    double fractionalComponent = modf(timeInSeconds, &unused);
    // Technically this might not be perfect, maybe 0.9995 is represented with a double just under that, but this seems good enough
    if (fractionalComponent >= 0.9995) {
        timeInSeconds = lround(timeInSeconds);
    }
    time_t integerTime = (time_t)timeInSeconds;
    integerTime += static_cast<time_t>(fallbackOffset);
    jjl_localtime_rz(timeZone, &integerTime, &components);
    components.tm_gmtoff += static_cast<long>(fallbackOffset);
    
    bool showYear = !!(options & kCFISO8601DateFormatWithYear);
    bool showDateSeparator = !!(options & kCFISO8601DateFormatWithDashSeparatorInDate);
    bool showMonth = !!(options & kCFISO8601DateFormatWithMonth);
    bool showDay = !!(options & kCFISO8601DateFormatWithDay);
    bool isInternetDateTime = (options & kCFISO8601DateFormatWithInternetDateTime) == kCFISO8601DateFormatWithInternetDateTime;
    // For some reason, the week of the year is never shown if all the components of internet date time are shown
    bool showWeekOfYear = !isInternetDateTime && !!(options & kCFISO8601DateFormatWithWeekOfYear);
    bool showDate = showYear || showMonth || showDay || showWeekOfYear;
    
    int32_t daysAfterFirstWeekday = (components.tm_wday - 1 + 7) % 7;
    int32_t year = components.tm_year + 1900;
    bool usePreviousYear = showWeekOfYear && daysAfterFirstWeekday - components.tm_yday > 7 - 4;
    bool useNextYear = showWeekOfYear && components.tm_yday - daysAfterFirstWeekday + 7 - JJLDaysInYear(year) >= 4;
    
    if (showYear) {
        int32_t yearToShow = year;
        if (usePreviousYear) {
            yearToShow--;
        } else if (useNextYear) {
            yearToShow++;
        }
        JJLPushNumber(&buffer, yearToShow, 4);
    }
    if (showMonth) {
        if (showDateSeparator && showYear) {
            *buffer++ = '-';
        }
        JJLPushNumber(&buffer, components.tm_mon + 1, 2);
    }
    if (showWeekOfYear) {
        if (showDateSeparator && (showYear || showMonth)) {
            *buffer++ = '-';
        }
        *buffer++ = 'W';
        int32_t week = 0;
        if (useNextYear) {
            week = 0;
        } else {
            int32_t daysToDivide = components.tm_yday - daysAfterFirstWeekday;
            if (usePreviousYear) {
                daysToDivide += JJLDaysInYear(year - 1);
            }
            week = daysToDivide / 7;
            // See if the first day of this year was considered part of that year or the previous one
            if (daysToDivide % 7 >= 4) {
                week++;
            }
        }
        JJLPushNumber(&buffer, week + 1, 2);
    }
    if (showDay) {
        if (showDateSeparator && (showYear || showMonth || showWeekOfYear)) {
            *buffer++ = '-';
        }
        if (showWeekOfYear) {
            JJLPushNumber(&buffer, daysAfterFirstWeekday + 1, 2);
        } else if (showMonth) {
            JJLPushNumber(&buffer, components.tm_mday, 2);
        } else {
            JJLPushNumber(&buffer, components.tm_yday + 1, 3);
        }
    }

    bool showTime = !!(options & kCFISO8601DateFormatWithTime);
    bool showTimeSeparator = !!(options & kCFISO8601DateFormatWithColonSeparatorInTime);
    bool timeSeparatorIsSpace = !!(options & kCFISO8601DateFormatWithSpaceBetweenDateAndTime);
    if (showTime) {
        if (showDate) {
            *buffer++ = timeSeparatorIsSpace ? ' ' : 'T';
        }
        JJLPushNumber(&buffer, components.tm_hour, 2);
        if (showTimeSeparator) {
            *buffer++ = ':';
        }
        JJLPushNumber(&buffer, components.tm_min, 2);
        if (showTimeSeparator) {
            *buffer++ = ':';
        }
        JJLPushNumber(&buffer, components.tm_sec, 2);
        if (showFractionalSeconds) {
            *buffer++ = '.';
            JJLFillBufferWithFractionalSeconds(timeInSeconds, &buffer);
        }
    }
    if (options & kCFISO8601DateFormatWithTimeZone) {
        int32_t offset = (int32_t)components.tm_gmtoff;
        if (offset == 0) {
            *buffer++ = 'Z';
        } else {
            char sign = '\0';
            if (offset < 0) {
                offset = -offset;
                sign = '-';
            } else {
                sign = '+';
            }
            bool showColonSeparatorInTimeZone = !!(options & kCFISO8601DateFormatWithColonSeparatorInTimeZone);
            int32_t hours = offset / (60 * 60);
            int32_t minutes = offset % (60 * 60) / 60;
            int32_t seconds = offset % 60;
            *buffer++ = sign;
            JJLPushNumber(&buffer, hours, 2);
            if (showColonSeparatorInTimeZone) {
                *buffer++ = ':';
            }
            JJLPushNumber(&buffer, minutes, 2);
            if (seconds > 0) {
                if (showColonSeparatorInTimeZone) {
                    *buffer++ = ':';
                }
                JJLPushNumber(&buffer, seconds, 2);
            }
        }
    }
}

static const int32_t kJJLDigits[][10] = {{0, 1, 2, 3, 4, 5, 6, 7, 8, 9}, {0, 10, 20, 30, 40, 50, 60, 70, 80, 90}, {0, 100, 200, 300, 400, 500, 600, 700, 800, 900}, {0, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000}};

static inline int32_t JJLConsumeNumber(const char **stringPtr, const char *end, int32_t maxLength, bool *errorOccurred) {
    const char *string = *stringPtr;
    int32_t length = 0;
    bool isNegative = false;
    if (unlikely(string < end && *string == '-')) {
        isNegative = true;
        string++;
    }
    while (&(string[length]) < end && (length < maxLength || maxLength == -1)) {
        char c = string[length];
        if (!('0' <= c && c <= '9')) {
            break;
        }
        length++;
    }
    if (unlikely(length > 4)) {
        return isNegative ? -atoi(string) : atoi(string);
    }

    if (unlikely(length == 0)) {
        *errorOccurred = true;
        return 0;
    }

    int32_t number = 0;
    for (int32_t i = 0; i < length; i++) {
        char c = string[length - 1 - i];
        if (unlikely(!('0' <= c && c <= '9'))) {
            *errorOccurred = true;
            return 0;
        }
        int32_t digit = c - '0';
        number += kJJLDigits[i][digit];
    }
    *stringPtr = string + length;
    return isNegative ? -number : number;
}

static inline void JJLConsumeCharacter(const char **string, const char *end, char c, bool *errorOccurred) {
    // Fixed: was "*string + 1 >= end" which is off-by-one
    if (unlikely(*string >= end || **string != c)) {
        *errorOccurred = true;
        return;
    }

    (*string)++;
}

static inline void JJLConsumeSeparator(const char **string, const char *end, bool *errorOccurred) {
    // Fixed: was "*string + 1 >= end" which is off-by-one
    if (unlikely(*string >= end)) {
        *errorOccurred = true;
        return;
    }

    char c = **string;
    if (unlikely(c != ' ' && c != '-' && c != ':')) {
        *errorOccurred = true;
        return;
    }
    (*string)++;
}

static int32_t JJLConsumeFractionalSeconds(const char **string, const char *end, bool *errorOccurred) {
    if (*string < end) {
        char c = **string;
        if (c == '.' || c == ',') {
            (*string)++;
        } else {
            *errorOccurred = true;
            return 0;
        }
    }

    const char *origString = *string;
    int32_t num = JJLConsumeNumber(string, end, 3, errorOccurred);
    int32_t length = (int32_t)(*string - origString);

    // Consume any leftover part of the decimal and discard it
    while (*string < end) {
        char c = **string;
        if (c < '0' || c > '9') {
            break;
        }
        (*string)++;
    }

    if (length == 0) {
        return 0;
    } else if (length == 1) {
        return num * 100;
    } else if (length == 2) {
        return num * 10;
    } else { // length == 3
        return num;
    }
}

static inline int32_t JJLConsumeTimeZone(const char **string, const char *end, bool separator, bool *errorOccurred) {
    if (*string >= end) {
        *errorOccurred = true;
        return 0;
    }

    if ((*string)[0] == 'Z') {
        (*string)++;
        return 0;
    } else {
        bool isNegative = false;
        if ((*string)[0] == '-') {
            isNegative = true;
        }
        (*string)++;
        int32_t hours = JJLConsumeNumber(string, end, 2, errorOccurred);
        if (separator) {
            JJLConsumeCharacter(string, end, ':', errorOccurred);
        }
        int32_t minutes = JJLConsumeNumber(string, end, 2, errorOccurred);
        int32_t seconds = 0;
        if (*string < end) { // ":xx" for the seconds
            if (separator) {
                JJLConsumeCharacter(string, end, ':', errorOccurred);
            }
            seconds = JJLConsumeNumber(string, end, 2, errorOccurred);
        }
        int32_t absValue = hours * 60 * 60 + minutes * 60 + seconds;
        return isNegative ? -absValue : absValue;
    }
}

// Use std::chrono to convert ISO week date to calendar date
static void JJLConvertISOWeekToCalendarDate(int32_t isoYear, int32_t isoWeek, int32_t isoDayOfWeek,
                                             int32_t *outYear, int32_t *outMonth, int32_t *outDay) {
    // Find Jan 4 of ISO year (always in week 1)
    year_month_day jan4{year{isoYear}, January, day{4}};
    sys_days jan4_days{jan4};
    
    // Find the Monday of week 1
    weekday jan4_weekday{jan4_days};
    int32_t jan4_dow = static_cast<int32_t>(jan4_weekday.iso_encoding()); // 1=Mon, 7=Sun
    sys_days week1_monday = jan4_days - days{jan4_dow - 1};
    
    // Calculate the target date
    sys_days target = week1_monday + weeks{isoWeek - 1} + days{isoDayOfWeek - 1};
    year_month_day ymd{target};
    
    *outYear = static_cast<int>(ymd.year());
    *outMonth = static_cast<unsigned>(ymd.month());
    *outDay = static_cast<unsigned>(ymd.day());
}

// Use std::chrono to convert day-of-year to month/day
static void JJLConvertDayOfYearToMonthDay(int32_t yearVal, int32_t dayOfYear,
                                           int32_t *outMonth, int32_t *outDay) {
    year_month_day jan1{year{yearVal}, January, day{1}};
    sys_days target = sys_days{jan1} + days{dayOfYear - 1};
    year_month_day ymd{target};
    
    *outMonth = static_cast<unsigned>(ymd.month());
    *outDay = static_cast<unsigned>(ymd.day());
}

extern "C" double JJLTimeIntervalForString(const char *string, int32_t length, CFISO8601DateFormatOptions options, timezone_t timeZone, bool *errorOccurred) {
    if ((options & (options - 1)) == 0) {
        *errorOccurred = true;
        return 0;
    }

    const char *origStringPosition = string;
    const char *end = origStringPosition + length;
    struct tm components = {0};

    bool showFractionalSeconds = JJLGetShowFractionalSeconds(options);

    bool showYear = !!(options & kCFISO8601DateFormatWithYear);
    bool showDateSeparator = !!(options & kCFISO8601DateFormatWithDashSeparatorInDate);
    bool showMonth = !!(options & kCFISO8601DateFormatWithMonth);
    bool showDay = !!(options & kCFISO8601DateFormatWithDay);
    bool showTime = !!(options & kCFISO8601DateFormatWithTime);
    bool showTimeSeparator = !!(options & kCFISO8601DateFormatWithColonSeparatorInTime);
    bool timeSeparatorIsSpace = !!(options & kCFISO8601DateFormatWithSpaceBetweenDateAndTime);
    bool showTimeZone = !!(options & kCFISO8601DateFormatWithTimeZone);
    bool isInternetDateTime = (options & kCFISO8601DateFormatWithInternetDateTime) == kCFISO8601DateFormatWithInternetDateTime;
    bool showColonSeparatorInTimeZone = options & kCFISO8601DateFormatWithColonSeparatorInTimeZone;
    bool showWeekOfYear = !isInternetDateTime && !!(options & kCFISO8601DateFormatWithWeekOfYear);
    bool showDate = showYear || showMonth || showDay || showWeekOfYear;
    
    int32_t yearValue = showYear ? JJLConsumeNumber(&string, end, 4, errorOccurred) : 2000;
    
    int32_t monthValue = 1;
    int32_t dayValue = 1;
    int32_t isoWeekValue = 0;
    int32_t isoDayOfWeek = 1;

    if (showMonth) {
        if (showDateSeparator && showYear) {
            JJLConsumeSeparator(&string, end, errorOccurred);
        }
        monthValue = JJLConsumeNumber(&string, end, 2, errorOccurred);
    }

    if (showWeekOfYear) {
        if (showDateSeparator && (showYear || showMonth)) {
            JJLConsumeSeparator(&string, end, errorOccurred);
        }
        JJLConsumeCharacter(&string, end, 'W', errorOccurred);
        isoWeekValue = JJLConsumeNumber(&string, end, 2, errorOccurred);
    }

    if (showDay) {
        if (showDateSeparator && (showYear || showMonth || showWeekOfYear)) {
            JJLConsumeSeparator(&string, end, errorOccurred);
        }
        int32_t dayNumber = JJLConsumeNumber(&string, end, -1, errorOccurred);
        
        if (showWeekOfYear) {
            isoDayOfWeek = dayNumber;
        } else if (showMonth) {
            dayValue = dayNumber;
        } else {
            // Day of year - use std::chrono to convert
            JJLConvertDayOfYearToMonthDay(yearValue, dayNumber, &monthValue, &dayValue);
        }
    }

    // Use std::chrono to convert ISO week date to calendar date if needed
    if (showWeekOfYear) {
        JJLConvertISOWeekToCalendarDate(yearValue, isoWeekValue, isoDayOfWeek,
                                         &yearValue, &monthValue, &dayValue);
    }

    components.tm_year = yearValue - 1900;
    components.tm_mon = monthValue - 1;
    components.tm_mday = dayValue;

    int32_t millis = 0;
    if (showTime) {
        if (showDate) {
            char separator = timeSeparatorIsSpace ? ' ' : 'T';
            JJLConsumeCharacter(&string, end, separator, errorOccurred);
        }
        components.tm_hour = JJLConsumeNumber(&string, end, 2, errorOccurred);
        if (showTimeSeparator) {
            JJLConsumeSeparator(&string, end, errorOccurred);
        }
        components.tm_min = JJLConsumeNumber(&string, end, 2, errorOccurred);
        if (showTimeSeparator) {
            JJLConsumeSeparator(&string, end, errorOccurred);
        }
        components.tm_sec = JJLConsumeNumber(&string, end, 2, errorOccurred);
        if (showFractionalSeconds) {
            millis = JJLConsumeFractionalSeconds(&string, end, errorOccurred);
        }
    }
    if (showTimeZone) {
        timeZone = sGMTTimeZone;
        components.tm_sec -= JJLConsumeTimeZone(&string, end, showColonSeparatorInTimeZone, errorOccurred);
    } else {
        components.tm_isdst = -1; // Let library decide
    }

    if (*errorOccurred) {
        return 0;
    }

    time_t time = jjl_mktime_z(timeZone, &components);
    return time + millis / 1000.0;
}

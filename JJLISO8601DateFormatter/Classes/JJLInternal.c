//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import <time.h>
#import <assert.h>
#import <string.h>
#import <CoreFoundation/CFDateFormatter.h>
#import <pthread.h>
#import <math.h>
#import <stdio.h>
#import "tzfile.h"
#import <stdlib.h>
#import <dispatch/dispatch.h>

#import "JJLInternal.h"
#import "itoa.h"

// void JJLGmtSub(time_t const *timep, struct tm *tmp);
// void gmtload(struct state *const sp);

static bool sIsIOS11OrHigher = false;

static const int32_t kJJLItoaStringsLength = 3000;
static const int32_t kJJLItoaEachStringLength = 4;

static char sItoaStrings[kJJLItoaStringsLength][kJJLItoaEachStringLength];

typedef struct {
    char *buffer;
    int32_t length;
} JJLString;

#define unlikely(x) __builtin_expect(!!(x), 0)

void JJLPerformInitialSetup() {
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
}

static inline void JJLPush(JJLString *string, char c) {
    if (unlikely(string->length + 1 >= JJL_MAX_DATE_LENGTH)) {
        return;
    }
    string->buffer[string->length] = c;
    string->length++;
}

static inline void JJLPushBuffer(JJLString *string, char *buffer, int32_t size) {
    memcpy(&(string->buffer[string->length]), buffer, size);
    string->length += size;
}

static inline void JJLPushNumber(JJLString *string, int32_t num, int32_t fixedDigitLength) {
    if (0 <= num && num < kJJLItoaStringsLength) {
        JJLPushBuffer(string, &(sItoaStrings[num][kJJLItoaEachStringLength - fixedDigitLength]), fixedDigitLength);
    } else {
        // Slow path, but will practically never be needed
        char str[5];
        snprintf(str, sizeof(str), "%d", num);
        JJLPushBuffer(string, str, (int32_t)strlen(str));
    }
}

static inline void JJLFillBufferWithFractionalSeconds(double time, JJLString *string) {
    double unused = 0;
    double fractionalComponent = modf(time, &unused);
    int32_t millis = (int32_t)lround(fractionalComponent * 1000);
    JJLPushNumber(string, millis, 3);
}

static inline int32_t JJLDaysInYear(int32_t year) {
    bool isLeap = (year % 400 == 0) || (year % 4 == 0 && year % 100 != 0);
    return isLeap ? 366 : 365;
}

static bool JJLGetShowFractionalSeconds(CFISO8601DateFormatOptions options)
{
    if (sIsIOS11OrHigher) {
        return !!(options & kCFISO8601DateFormatWithFractionalSeconds);
    } else {
        return false;
    }
}

void JJLFillBufferForDate(char *buffer, double timeInSeconds, bool local, CFISO8601DateFormatOptions options, timezone_t timeZone, double fallbackOffset) {
    if ((options & (options - 1)) == 0) {
        return;
    }
    JJLString string = {0};
    string.buffer = buffer;
    struct tm components = {0};

    bool showFractionalSeconds = JJLGetShowFractionalSeconds(options);

    double unused = 0;
    double fractionalComponent = modf(timeInSeconds, &unused);
    // Technically this might not be perfect, maybe 0.9995 is represented with a double just under that, but this seems good enough
    if (fractionalComponent >= 0.9995) {
        timeInSeconds = lround(timeInSeconds);
    }
    time_t integerTime = (time_t)timeInSeconds;
    integerTime += fallbackOffset;
    jjl_localtime_rz(timeZone, &integerTime, &components);
    components.tm_gmtoff += fallbackOffset;
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
        JJLPushNumber(&string, yearToShow, 4);
    }
    if (showMonth) {
        if (showDateSeparator && showYear) {
            JJLPush(&string, '-');
        }
        JJLPushNumber(&string, components.tm_mon + 1, 2);
    }
    if (showWeekOfYear) {
        if (showDateSeparator && (showYear || showMonth)) {
            JJLPush(&string, '-');
        }
        JJLPush(&string, 'W');
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
        JJLPushNumber(&string, week + 1, 2);
    }
    if (showDay) {
        if (showDateSeparator && (showYear || showMonth || showWeekOfYear)) {
            JJLPush(&string, '-');
        }
        if (showWeekOfYear) {
            JJLPushNumber(&string, daysAfterFirstWeekday + 1, 2);
        } else if (showMonth) {
            JJLPushNumber(&string, components.tm_mday, 2);
        } else {
            JJLPushNumber(&string, components.tm_yday + 1, 3);
        }
    }

    bool showTime = !!(options & kCFISO8601DateFormatWithTime);
    bool showTimeSeparator = !!(options & kCFISO8601DateFormatWithColonSeparatorInTime);
    bool timeSeparatorIsSpace = !!(options & kCFISO8601DateFormatWithSpaceBetweenDateAndTime);
    if (showTime) {
        if (showDate) {
            char separator = timeSeparatorIsSpace ? ' ' : 'T';
            JJLPush(&string, separator);
        }
        JJLPushNumber(&string, components.tm_hour, 2);
        if (showTimeSeparator) {
            JJLPush(&string, ':');
        }
        JJLPushNumber(&string, components.tm_min, 2);
        if (showTimeSeparator) {
            JJLPush(&string, ':');
        }
        JJLPushNumber(&string, components.tm_sec, 2);
        if (showFractionalSeconds) {
            JJLPush(&string, '.');
            JJLFillBufferWithFractionalSeconds(timeInSeconds, &string);
        }
    }
    if (options & kCFISO8601DateFormatWithTimeZone) {
        int32_t offset = (int32_t)components.tm_gmtoff;
        if (offset == 0) {
            JJLPush(&string, 'Z');
        } else {
            char sign = '\0';
            if (offset < 0) {
                offset = -offset;
                sign = '-';
            } else {
                sign = '+';
            }
            int32_t hours = offset / (60 * 60);
            int32_t minutes = offset % (60 * 60) / 60;
            int32_t seconds = offset % 60;
            JJLPush(&string, sign);
            JJLPushNumber(&string, hours, 2);
            JJLPush(&string, ':');
            JJLPushNumber(&string, minutes, 2);
            if (seconds > 0) {
                JJLPush(&string, ':');
                JJLPushNumber(&string, seconds, 2);
            }
        }
    }
}

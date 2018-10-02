//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import <time.h>
#import <assert.h>
#import <string.h>
#import <CoreFoundation/CFDateFormatter.h>
#import <pthread.h>
#import <math.h>
#import <stdio.h>
#import "tzfile.h"

#import "JJLInternal.h"
#import "itoa.h"

// void JJLGmtSub(time_t const *timep, struct tm *tmp);
// void gmtload(struct state *const sp);

typedef struct {
    char *buffer;
    int32_t length;
} JJLString;

static inline void JJLPush(JJLString *string, char c) {
    string->buffer[string->length] = c;
    string->length++;
}

static inline void JJLPushBuffer(JJLString *string, char *buffer, int32_t size) {
    memcpy(&(string->buffer[string->length]), buffer, size);
    string->length += size;
}

static inline void JJLFillBufferWithUpTo19(int month, JJLString *string) {
    assert(1 <= month && month <= 12);
    if (month < 10) {
        JJLPush(string, '0');
        JJLPush(string, month + '0');
    } else {
        JJLPush(string, '1');
        JJLPush(string, month - 10 + '0');
    }
}

static inline void JJLFillBufferWithFractionalSeconds(double time, JJLString *string) {
    double unused = 0;
    double fractionalComponent = modf(time, &unused);
    /*int32_t millis = (int32_t)lround(fractionalComponent * 1000);
    char chars[5] = {0}; // Extra byte just being extra safe
    char *charsPtr = (char *)chars;
    i32toa(millis, charsPtr);
    int length = (int)strlen(charsPtr);
    for (int i = 0; i < 3 - length; i++) {
        JJLPush(string, '0');
    }
    JJLPushBuffer(string, charsPtr, length);*/
    // the printf way:
    char buffer[7];
    char *bufferPtr = (char *)buffer;
    // Use the fractionalComponent to be sure that we don't pass in some huge double that would fill the buffer before it hits the fractional component
    snprintf(bufferPtr, sizeof(buffer), "%.3f", fractionalComponent);
    char *decimalPointStr = strchr(buffer, '.');
    char *decimalStr = decimalPointStr + 1;
    JJLPushBuffer(string, decimalStr, (int32_t)strlen(decimalStr));
}

// Requires buffer to be at least 5 bytes
static inline void JJLFillBufferWithYear(int year, JJLString *string) {
    if (2010 <= year && year <= 2019) {
        char end = year - 2010 + '0';
        char year[4] = {'2', '0', '1', end};
        JJLPushBuffer(string, year, sizeof(year));
        return;
    }

    if (2020 <= year && year <= 2029) {
        char end = year - 2020 + '0';
        char year[4] = {'2', '0', '2', end};
        JJLPushBuffer(string, year, sizeof(year));
        return;
    }

    uint32_t u = (uint32_t)year;
    if (year < 0) {
        JJLPush(string, '-');
        u = ~u + 1;
    }
    if (u < 10) {
        JJLPush(string, '0');
    }
    if (u < 100) {
        JJLPush(string, '0');
    }
    if (u < 1000) {
        JJLPush(string, '0');
    }
    char *newEnd = u32toa(u, &(string->buffer[string->length]));
    string->length += newEnd - string->buffer;
}

static inline void JJLFillBufferWithUpTo69(int time, JJLString *string) {
    assert(0 <= time && time <= 60);
    int32_t tens = 0;
    if (time >= 30) {
        tens += 3;
        time -= 30;
    }
    if (time >= 10) {
        tens += 1;
        time -= 10;
        if (time >= 10) {
            tens += 1;
            time -= 10;
            if (time >= 10) { // Last one for leap seconds
                tens += 1;
                time -= 10;
            }
        }
    }

    JJLPush(string, '0' + tens);
    JJLPush(string, '0' + time);
    return;
}

static inline bool JJLIsLeapYear(int32_t year) {
    return (year % 400 == 0) || (year % 4 == 0 && year % 100 != 0);
}

/*void JJLFillSeparator(JJLString *string, CFISO8601DateFormatOptions currentOption, CFISO8601DateFormatOptions previousOption, CFISO8601DateFormatOptions options) {
    // needs CFCalendarUnit
    char separator = 0;
    // is this if statement needed?
    if (previousOption == 0) { // Indicates that this is the first option being printed
        if (currentOption == kCFISO8601DateFormatWithWeekOfYear) {
            separator = 'W';
        }
    } else {
        CFISO8601DateFormatOptions dateMask = kCFISO8601DateFormatWithYear | kCFISO8601DateFormatWithWeekOfYear | kCFISO8601DateFormatWithMonth | kCFISO8601DateFormatWithDay;
        CFISO8601DateFormatOptions timeMask = kCFISO8601DateFormatWithTime | kCFISO8601DateFormatWithFullTime;
        bool previousIsDate = previousOption & dateMask;
        bool previousIsTime = previousOption & timeMask;
        bool currentIsDate = currentOption & dateMask;
        bool currentIsTime = currentOption & timeMask;
        if (previousIsDate && currentIsDate) {
            if (options & kCFISO8601DateFormatWithDashSeparatorInDate)  {
                separator = '-';
            }
        } else if (previousIsDate && currentIsTime) {
            bool useSpace = options & kCFISO8601DateFormatWithSpaceBetweenDateAndTime;
            separator = useSpace ? ' ' : 'T';
        } else if (previousIsTime && currentIsTime) {
            if (kCFISO8601DateFormatWithColonSeparatorInTime) {
                separator = ':';
            }
        }
    }
    if (separator != 0) {
        JJLPush(string, separator);
    }
}*/

bool JJLGetShowFractionalSeconds(CFISO8601DateFormatOptions options) {
    if (__builtin_available(iOS 11.0, *)) {
        return !!(options & kCFISO8601DateFormatWithFractionalSeconds);
    } else {
        return false;
    }
}

void JJLFillBufferForDate(char *buffer, double timeInSeconds, int32_t firstWeekday, bool local, CFISO8601DateFormatOptions options, timezone_t timeZone, double fallbackOffset) {
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
    if (local) {
        localtime_r(&integerTime, &components);
    } else {
        jjl_localtime_rz(timeZone, &integerTime, &components);
        //gmtime_r(&integerTime, &components);
    }
    components.tm_gmtoff += fallbackOffset;
    // timeInSeconds -= components.tm_gmtoff;
    bool showYear = !!(options & kCFISO8601DateFormatWithYear);
    bool showDateSeparator = !!(options & kCFISO8601DateFormatWithDashSeparatorInDate);
    bool showMonth = !!(options & kCFISO8601DateFormatWithMonth);
    bool showDay = !!(options & kCFISO8601DateFormatWithDay);
    bool isInternetDateTime = (options & kCFISO8601DateFormatWithInternetDateTime) == kCFISO8601DateFormatWithInternetDateTime;
    // For some reason, the week of the year is never shown if all the components of internet date time are shown
    bool showWeekOfYear = !isInternetDateTime && !!(options & kCFISO8601DateFormatWithWeekOfYear);
    bool showDate = showYear || showMonth || showDay || showWeekOfYear;
    int32_t daysAfterFirstWeekday = (components.tm_wday - firstWeekday + 7) % 7;
    int32_t year = components.tm_year + 1900;
    int32_t daysTillFirstWeekday = 7 - daysAfterFirstWeekday;
    bool usePreviousYear = showWeekOfYear && components.tm_yday < daysTillFirstWeekday;
    if (showYear) {
        int32_t yearToShow = usePreviousYear ? year - 1 : year;
        JJLFillBufferWithYear(yearToShow, &string);
    }
    if (showMonth) {
        if (showDateSeparator && showYear) {
            JJLPush(&string, '-');
        }
        JJLFillBufferWithUpTo69(components.tm_mon + 1, &string);
    }
    if (showWeekOfYear) {
        if (showDateSeparator && (showYear || showMonth)) {
            JJLPush(&string, '-');
        }
        JJLPush(&string, 'W');
        // todo: figure out if it's locale-sensitive, because the first week of the year can change
        int32_t daysToDivide = components.tm_yday - daysAfterFirstWeekday;
        if (usePreviousYear) {
            daysToDivide += JJLIsLeapYear(year - 1) ? 366 : 365;
        }
        int32_t week = daysToDivide / 7;
        JJLFillBufferWithUpTo69(week + 1, &string);
    }
    if (showDay) {
        if (showDateSeparator && (showYear || showMonth || showWeekOfYear)) {
            JJLPush(&string, '-');
        }
        if (showWeekOfYear) {
            JJLFillBufferWithUpTo19(daysTillFirstWeekday, &string);
        } else if (showMonth) {
            JJLFillBufferWithUpTo69(components.tm_mday, &string);
        } else {
            // Could be optimized, but seems like a rare case
            char *newEnd = i32toa(components.tm_yday + 1, &(string.buffer[string.length]));
            string.length = (int32_t)(newEnd - string.buffer);
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
        JJLFillBufferWithUpTo69(components.tm_hour, &string);
        if (showTimeSeparator) {
            JJLPush(&string, ':');
        }
        JJLFillBufferWithUpTo69(components.tm_min, &string);
        if (showTimeSeparator) {
            JJLPush(&string, ':');
        }
        JJLFillBufferWithUpTo69(components.tm_sec, &string);
        // @availability is not available, so use __builtin instead
        if (__builtin_available(iOS 11.0, *)) {
            if (showFractionalSeconds) {
                JJLPush(&string, '.');
                JJLFillBufferWithFractionalSeconds(timeInSeconds, &string);
            }
        }
    }
    if (options & kCFISO8601DateFormatWithTimeZone) {
        long offset = components.tm_gmtoff;
        if (offset == 0) {
            JJLPush(&string, 'Z');
        } else {
            char sign = '\0';
            if (offset < 0) {
                offset *= -1;
                sign = '-';
            } else {
                sign = '+';
            }
            int32_t minutes = offset / 60;
            int32_t hours = minutes / 60;
            int32_t remainderMinutes = minutes % 60;
            JJLPush(&string, sign);
            JJLFillBufferWithUpTo69(hours, &string);
            JJLPush(&string, ':');
            JJLFillBufferWithUpTo69(remainderMinutes, &string);
        }
    }
}

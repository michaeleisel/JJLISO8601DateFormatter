//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import <time.h>
#import <assert.h>
#import <string.h>
#import <CoreFoundation/CFDateFormatter.h>
#import <pthread.h>

#import "JJLInternal.h"
#import "itoa.h"

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

static inline void JJLFillBufferWithUpTo60(int time, JJLString *string) {
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

void JJLFillBufferForDate(char *buffer, time_t timeInSeconds, bool local, CFISO8601DateFormatOptions options) {
    if ((options & (options - 1)) == 0) {
        return;
    }
    JJLString string = {0};
    string.buffer = buffer;
    struct tm components = {0};
    if (local) {
        localtime_r(&timeInSeconds, &components);
    } else {
        gmtime_r(&timeInSeconds, &components);
    }
    // timeInSeconds -= components.tm_gmtoff;
    bool showYear = !!(options & kCFISO8601DateFormatWithYear);
    bool showDateSeparator = !!(options & kCFISO8601DateFormatWithDashSeparatorInDate);
    bool showMonth = !!(options & kCFISO8601DateFormatWithMonth);
    bool showDay = !!(options & kCFISO8601DateFormatWithDay);
    bool showWeekOfYear = !!(options & kCFISO8601DateFormatWithWeekOfYear);
    bool showDate = showYear || showMonth || showDay || showWeekOfYear;
    int32_t daysAfterMonday = (components.tm_wday - 1 + 7) % 7;
    int32_t year = components.tm_year + 1900;
    int32_t daysTillMonday = (7 - daysAfterMonday) % 7;
    bool usePreviousYear = showWeekOfYear && components.tm_yday < daysTillMonday;
    if (showYear) {
        int32_t yearToShow = usePreviousYear ? year - 1 : year;
        JJLFillBufferWithYear(yearToShow, &string);
    }
    if (showMonth) {
        if (showDateSeparator && showYear) {
            JJLPush(&string, '-');
        }
        JJLFillBufferWithUpTo60(components.tm_mon + 1, &string);
    }
    if (showWeekOfYear) {
        JJLPush(&string, 'W');
        // todo: figure out if it's locale-sensitive, because the first week of the year can change
        int32_t daysToDivide = components.tm_yday - daysAfterMonday;
        if (usePreviousYear) {
            daysToDivide += JJLIsLeapYear(year - 1) ? 366 : 365;
        }
        int32_t week = daysToDivide / 7;
        JJLFillBufferWithUpTo60(week + 1, &string);
    }
    if (showDay) {
        if (showDateSeparator && (showYear || showMonth || showWeekOfYear)) {
            JJLPush(&string, '-');
        }
        if (showWeekOfYear) {
            JJLFillBufferWithUpTo19(daysAfterMonday, &string);
        } else if (showMonth) {
            JJLFillBufferWithUpTo60(components.tm_mday, &string);
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
        JJLFillBufferWithUpTo60(components.tm_hour, &string);
        if (showTimeSeparator) {
            JJLPush(&string, ':');
        }
        JJLFillBufferWithUpTo60(components.tm_min, &string);
        if (showTimeSeparator) {
            JJLPush(&string, ':');
        }
        JJLFillBufferWithUpTo60(components.tm_sec, &string);
        JJLPush(&string, 'Z');
    }
}

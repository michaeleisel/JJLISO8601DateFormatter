// Copyright (c) 2018 Michael Eisel. All rights reserved.

#import "JJLISO8601DateFormatter.h"
#import "itoa.h"

#define JJL_ALWAYS_INLINE __attribute__((always_inline))

// Note: this class does not use ARC

static const NSInteger kJJLMaxLength = 40;

@implementation JJLISO8601DateFormatter

// allow for "+" unary operator
// asserts for invalid minute, year, etc.?
// todo: sizeof long?
// todo: max length correct? large numbers?
// distant future? distant past?
// todo: NSFormatter subclassing and secure coding!
// todo: do MRC properties automatically retain and release?
-(id)init
{
    self = [super init];
    if (self) {
        _formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithDashSeparatorInDate | NSISO8601DateFormatWithColonSeparatorInTime | NSISO8601DateFormatWithColonSeparatorInTimeZone;
    }
    return self;
}

- (NSString *)stringFromDate:(NSDate *)date
{
    return JJLStringFromDate(date, nil, _formatOptions);
}

- (nullable NSDate *)dateFromString:(NSString *)string
{
    return nil;
}

+ (NSString *)stringFromDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone formatOptions:(NSISO8601DateFormatOptions)formatOptions
{
    return @"";
}

typedef char JJLBuffer[kJJLMaxLength];

#define JJL_COPY(...) \
({ \
char __tmpBuffer[] = {__VA_ARGS__}; \
memcpy(buffer, __tmpBuffer, sizeof(__tmpBuffer)); \
(*bufferPtr) += sizeof(__tmpBuffer); \
})

static JJL_ALWAYS_INLINE NSString *JJLStringFromDate(NSDate *date, NSTimeZone *timeZone, NSISO8601DateFormatOptions formatOptions)
{
    if (!timeZone) {
        timeZone = [NSTimeZone defaultTimeZone];
    }
    JJLBuffer bufferStruct = {0};
    char *buffer = (char *)bufferStruct;
    char **bufferPtr = &buffer;
    char *start = &(buffer[0]);
    struct tm components = {0};
    time_t time = date.timeIntervalSince1970 - [timeZone secondsFromGMTForDate:date];
    localtime_r(&time, &components);
    JJLFillBufferWithYear(components.tm_year + 1900, &buffer);
    JJL_COPY('-');
    JJLFillBufferWithMonth(components.tm_mon + 1, &buffer);
    JJL_COPY('-');
    JJLFillBufferWithUpTo60(components.tm_mday, &buffer);
    JJL_COPY('T');
    JJLFillBufferWithUpTo60(components.tm_hour, &buffer);
    JJL_COPY(':');
    JJLFillBufferWithUpTo60(components.tm_min, &buffer);
    JJL_COPY(':');
    JJLFillBufferWithUpTo60(components.tm_sec, &buffer);
    JJL_COPY('Z');
    // JJL_COPY('-');
    // JJL_COPY(':');
    /*if (components) {
        <#statements#>
    }
    string[];*/
    return CFAutorelease(CFStringCreateWithCString(kCFAllocatorDefault, start, kCFStringEncodingUTF8));
}

static inline void JJLFillBufferWithMonth(int month, char **bufferPtr) {
    NSCAssert(1 <= month && month <= 12, @"");
    char *buffer = *bufferPtr;
    if (month < 10) {
        JJL_COPY('0', month + '0');
    } else {
        JJL_COPY('1', month - 10 + '0');
    }
}

// Requires buffer to be at least 5 bytes
static inline void JJLFillBufferWithYear(int year, char **bufferPtr) {
    char *buffer = *bufferPtr;
    if (2010 <= year && year <= 2019) {
        JJL_COPY('2', '0', '1', year - 2010 + '0');
        return;
    }

    if (2020 <= year && year <= 2029) {
        JJL_COPY('2', '0', '2', year - 2010 + '0');
        return;
    }

    uint32_t u = (uint32_t)year;
    if (year < 0) {
        *buffer++ = '-';
        u = ~u + 1;
    }
    if (u < 10) {
        *buffer++ = '0';
    }
    if (u < 100) {
        *buffer++ = '0';
    }
    if (u < 1000) {
        *buffer++ = '0';
    }
    u32toa(u, buffer); // ignore return value
    (*bufferPtr) += strlen(*bufferPtr);
}

static inline void JJLFillBufferWithUpTo60(int time, char **bufferPtr) {
    NSCAssert(0 <= time && time <= 60, @"");
    char *buffer = *bufferPtr;
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

    JJL_COPY('0' + tens, '0' + time);
    return;
}

@end

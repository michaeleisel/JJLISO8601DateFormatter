// Copyright (c) 2018 Michael Eisel. All rights reserved.

#import "JJLISO8601DateFormatter.h"
#import "itoa.h"
#import "JJLInternal.h"

#define JJL_ALWAYS_INLINE __attribute__((always_inline))

// Note: this class does not use ARC

@implementation JJLISO8601DateFormatter

// todo: does the C assert function turn off in release?
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

static JJL_ALWAYS_INLINE NSString *JJLStringFromDate(NSDate *date, NSTimeZone *timeZone, NSISO8601DateFormatOptions formatOptions)
{
    /*if (!timeZone) {
        timeZone = [NSTimeZone defaultTimeZone];
    }*/
    char bufferStruct[kJJLMaxLength] = {0};
    char *buffer = (char *)bufferStruct;
    time_t time = date.timeIntervalSince1970;// - [timeZone secondsFromGMTForDate:date];
    JJLFillBufferForDate(buffer, time);
    return CFAutorelease(CFStringCreateWithCString(kCFAllocatorDefault, buffer, kCFStringEncodingUTF8));
}

@end
